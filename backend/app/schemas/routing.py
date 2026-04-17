from pydantic import BaseModel
from typing import List, Optional, Literal

class LocationPoint(BaseModel):
    lat: float
    lng: float

class NearestStop(BaseModel):
    stop_id: int
    stop_name: Optional[str] = None
    distance_meters: float
    latitude: float
    longitude: float

class BusRoute(BaseModel):
    route_id: int
    route_name: str
    route_type: str
    is_direct: bool
    start_sequence: Optional[int] = None
    end_sequence: Optional[int] = None
    distance_meters: Optional[float] = None
    fare_nrs: Optional[float] = None
    estimated_time_seconds: Optional[float] = None

class TransferRoute(BaseModel):  # ← only ONE definition
    first_route_id: int
    first_route_name: str
    transfer_stop_id: int
    transfer_stop_name: Optional[str] = None
    second_route_id: int
    second_route_name: str
    total_stop_count: Optional[int] = None
    transfer_walk_meters: Optional[float] = None
    total_distance_meters: Optional[float] = None

class WalkingSegment(BaseModel):
    seq: int
    way_id: Optional[int] = None
    way_name: Optional[str] = None
    length_meters: Optional[float] = None
    cost: float
    geometry: dict

class StopInfo(BaseModel):
    stop_id: int
    stop_name: Optional[str] = None
    latitude: float
    longitude: float

class JourneyLeg(BaseModel):
    leg_type: Literal["walk", "bus"]
    description: str
    segments: Optional[List[WalkingSegment]] = None
    route: Optional[BusRoute] = None
    fare_nrs: Optional[float] = None
    distance_meters: Optional[float] = None
    board_stop: Optional[StopInfo] = None 
    alight_stop: Optional[StopInfo] = None 
    transfer_stop: Optional[StopInfo] = None

class CompleteJourney(BaseModel):
    start_location: Optional[LocationPoint] = None
    end_location: Optional[LocationPoint] = None
    nearest_start_stops: List[NearestStop] = []
    nearest_end_stops: List[NearestStop] = []
    closest_start_stop: Optional[NearestStop] = None
    closest_end_stop: Optional[NearestStop] = None
    direct_routes: List[BusRoute] = []
    transfer_routes: List[TransferRoute] = []
    has_direct_route: bool = False
    walking_to_start: Optional[List[WalkingSegment]] = None
    walking_from_end: Optional[List[WalkingSegment]] = None
    journey_legs: List[JourneyLeg] = []
    total_fare_nrs: float = 0.0
    total_distance_meters: float = 0.0
    total_estimated_time_seconds: float = 0.0
    error_message: Optional[str] = None

class RouteStop(BaseModel):
    sequence: int
    stop_id: int
    stop_name: Optional[str] = None
    latitude: float
    longitude: float

class RouteDetails(BaseModel):
    route_id: int
    route_name: str
    route_type: str
    total_distance_meters: float
    estimated_time_seconds: float
    fare_nrs: float = 0.0
    geometry: dict
    stops: List[RouteStop]