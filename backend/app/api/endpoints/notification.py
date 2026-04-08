from fastapi import APIRouter, Depends, BackgroundTasks, HTTPException
from sqlalchemy.orm import Session
from geoalchemy2.functions import ST_DWithin, ST_MakePoint, ST_SetSRID, ST_Distance
from sqlalchemy import cast
from geoalchemy2 import Geography

from app.core.database import get_db
from app.core.security import get_current_user
from app.model.poi import POI
from app.model.notification import Notification
from app.schemas.notif import (
    NotificationOut, ProximityCheckRequest, ProximityCheckResponse
)
from app.crud import notification as notif_crud
from app.services.fcm_service import send_push

router = APIRouter(prefix="/notifications", tags=["notifications"])

def _push_and_save(
    db: Session,
    user_id: int,
    fcm_token: str,
    nearby: list[dict],
):
    """Background task: send FCM push + persist a Notification row per POI."""
    for poi in nearby:
        title = f"You're near {poi['name']}!"
        body  = f"{poi['name']} is {poi['distance_meters']:.0f} m away."
        send_push(
            fcm_token, title, body,
            data={"poi_id": poi["id"], "type": "proximity"},
        )
        notif_crud.create_notification(
            db,
            data=__import__("app.schemas.notification", fromlist=["NotificationCreate"])
                .NotificationCreate(
                    user_id=user_id,
                    poi_id=poi["id"],
                    title=title,
                    message=body,
                ),
        )
        
@router.post("/proximity-check", response_model=ProximityCheckResponse)
def proximity_check(
    payload: ProximityCheckRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
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

    print(f"Nearby POIs: {nearby}")  # Debugging

    if nearby:
        background_tasks.add_task(
            _push_and_save, db, current_user.id, payload.fcm_token, nearby
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