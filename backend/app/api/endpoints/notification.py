from fastapi import APIRouter, Depends, BackgroundTasks, HTTPException
from sqlalchemy.orm import Session
from geoalchemy2.functions import ST_DWithin, ST_MakePoint, ST_SetSRID, ST_Distance
from sqlalchemy import cast
from geoalchemy2 import Geography
from app.model.user import User

from app.core.database import get_db, SessionLocal
from app.core.security import get_current_user
from app.model.poi import POI
from app.model.notification import Notification
from app.schemas.notif import (
    NotificationOut, ProximityCheckRequest, ProximityCheckResponse, NotificationCreate
)
from app.crud import notification as notif_crud
from app.services.fcm_service import send_push

router = APIRouter()

def _push_and_save(user_id, fcm_token, nearby):
    db = SessionLocal()
    try:
        for poi in nearby:
            # ← skip if notified recently
            if notif_crud.was_recently_notified(db, user_id, poi["id"]):
                continue

            title = f"You're near {poi['name']}!"
            body  = f"{poi['name']} is {poi['distance_meters']:.0f}m away."
            send_push(fcm_token, title, body,
                      data={"poi_id": str(poi["id"]), "type": "proximity"})
            notif_crud.create_notification(
                db,
                data=NotificationCreate(
                    user_id=user_id, poi_id=poi["id"],
                    title=title, message=body,
                ),
            )
    finally:
        db.close()
        
@router.post("/proximity-check", response_model=ProximityCheckResponse)
def proximity_check(
    payload: ProximityCheckRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    # Read token from DB instead of payload
    user = db.query(User).filter(User.id == current_user.id).first()
    fcm_token = user.fcm_token if user else None

    user_point = cast(
        ST_SetSRID(ST_MakePoint(payload.longitude, payload.latitude), 4326),
        Geography,
    )

    rows = (
        db.query(
            POI.id,
            POI.name,
            ST_Distance(cast(POI.geom, Geography), user_point).label("distance_meters"),
        )
        .filter(
            ST_DWithin(cast(POI.geom, Geography), user_point, payload.radius_meters)
        )
        .all()
    )

    nearby = [
        {"id": r.id, "name": r.name, "distance_meters": float(r.distance_meters)}
        for r in rows
    ]

    if nearby and fcm_token:
        background_tasks.add_task(
            _push_and_save, current_user.id, fcm_token, nearby
        )
    elif nearby and not fcm_token:
        # No FCM token — still save to inbox
        background_tasks.add_task(
            _push_and_save, current_user.id, None, nearby
        )

    return ProximityCheckResponse(triggered=bool(nearby), nearby_pois=nearby)

@router.get("/", response_model=list[NotificationOut])
def list_notifications(
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    return notif_crud.get_notifications_for_user(db, current_user.id, skip, limit)

@router.patch("/{notification_id}/read", response_model=NotificationOut)
def mark_read(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    notif = notif_crud.mark_as_read(db, notification_id, current_user.id)
    if not notif:
        raise HTTPException(404, "Notification not found")
    return notif

@router.patch("/read-all", response_model=dict)
def mark_all_read(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    count = notif_crud.mark_all_read(db, current_user.id)
    return {"marked_read": count}

@router.delete("/clear-all", status_code=204)
def delete_all_notifications(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    db.query(Notification).filter(
        Notification.user_id == current_user.id
    ).delete()
    db.commit()

@router.delete("/{notification_id}", status_code=204)
def delete_notification(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    notif = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == current_user.id, 
    ).first()
    if not notif:
        raise HTTPException(404, "Notification not found")
    db.delete(notif)
    db.commit()