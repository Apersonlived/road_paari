from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class NotificationCreate(BaseModel):
    user_id: int
    poi_id: Optional[int] = None
    title: str
    message: str


class NotificationOut(BaseModel):
    id: int
    user_id: int
    poi_id: Optional[int] = None
    title: str
    message: str
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True


class ProximityCheckRequest(BaseModel):
    # Check if it's near any POI
    latitude: float
    longitude: float
    radius_meters: float = 1000 # alert radius
    fcm_token: str # device FCM token to push to


class ProximityCheckResponse(BaseModel):
    triggered: bool
    nearby_pois: list[dict]  # contains the name of poi & distance from device