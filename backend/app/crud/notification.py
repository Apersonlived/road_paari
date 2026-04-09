from sqlalchemy.orm import Session
from app.model.notification import Notification
from app.schemas.notif import NotificationCreate
from datetime import datetime, timedelta
from sqlalchemy import and_

def create_notification(db: Session, data: NotificationCreate) -> Notification:
    notif = Notification(
        user_id=data.user_id,
        poi_id=data.poi_id,
        title=data.title,
        message=data.message,
    )
    db.add(notif)
    db.commit()
    db.refresh(notif)
    return notif

def get_notifications_for_user(
    db: Session, user_id: int, skip: int = 0, limit: int = 50
) -> list[Notification]:
    return (
        db.query(Notification)
        .filter(Notification.user_id == user_id)
        .order_by(Notification.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )

def mark_as_read(db: Session, notification_id: int, user_id: int) -> Notification | None:
    notif = (
        db.query(Notification)
        .filter(Notification.id == notification_id, Notification.user_id == user_id)
        .first()
    )
    if notif:
        notif.is_read = True
        db.commit()
        db.refresh(notif)
    return notif

def mark_all_read(db: Session, user_id: int) -> int:
    updated = (
        db.query(Notification)
        .filter(Notification.user_id == user_id, Notification.is_read == False)
        .update({"is_read": True})
    )
    db.commit()
    return updated

def was_recently_notified(
    db: Session,
    user_id: int,
    poi_id: int,
    cooldown_hours: int = 24,
) -> bool:
    cutoff = datetime.utcnow() - timedelta(hours=cooldown_hours)
    return db.query(Notification).filter(
        and_(
            Notification.user_id == user_id,
            Notification.poi_id  == poi_id,
            Notification.created_at >= cutoff,
        )
    ).first() is not None