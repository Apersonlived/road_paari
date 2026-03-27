from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class FCMTokenUpdate(BaseModel):
    fcm_token: str

class LocationPing(BaseModel):
    """
    Sent by the Flutter app periodically with the user's current location.
    The backend checks POI proximity and sends notifications as needed.
    """
    lat: float
    lng: float
    radius_meters: float = 200
 
 
class ProximityNotifyRequest(BaseModel):
    """Admin-triggered broadcast near a specific POI."""
    poi_id: int
    lat: float # POI's latitude  — pass poi.latitude
    lng: float # POI's longitude — pass poi.longitude
    radius_meters: float = 300
    title: Optional[str] = None
    body: Optional[str] = None

class NotificationOut(BaseModel):
    id: int
    user_id: int
    poi_id: Optional[int] = None
    title: Optional[str] = None
    message: Optional[str] = None
    is_read: bool
    created_at: datetime
 
    class Config:
        from_attributes = True

class NotificationResponse(BaseModel):
    success: bool
    sent_to: int
    message: Optional[str] = None

class UnreadCountResponse(BaseModel):
    unread_count: int