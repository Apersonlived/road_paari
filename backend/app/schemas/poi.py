from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class POICategoryBase(BaseModel):
    name: str
    description: Optional[str] = None

class POICategoryCreate(POICategoryBase):
    pass

class POICategory(POICategoryBase):
    id: int
    
    class Config:
        from_attributes = True

class POIBase(BaseModel):
    name: str
    description: Optional[str] = None
    category_id: Optional[int] = None

class POICreate(POIBase):
    latitude: float
    longitude: float

class POIUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    category_id: Optional[int] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None

class POI(POIBase):
    id: int
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    created_at: datetime
    created_by: Optional[int] = None
    
    class Config:
        from_attributes = True

class POIWithDistance(POI):
    distance_meters: Optional[float] = None