from pydantic import BaseModel
from typing import List, Optional, Literal, Union, Any

class LocationPoint(BaseModel):
    lat: float
    lng: float

class NearestStop(BaseModel):
    stop_id: int
    stop_name: Optional[str] = None
    distance_meters: float
    latitude: float
    longitude: float

class TransferRoute(BaseModel):
    first_route_id: int
    first_route_name: str
    transfer_stop_id: int
    transfer_stop_name: str
    second_route_id: int
    second_route_name: str

class WalkingSegment(BaseModel):
    seq: int
    way_id: Optional[int] = None
    way_name: Optional[str] = None
    length_meters: Optional[float] = None
    cost: float
    geometry: dict

class BusRoute(BaseModel):
    route_id: int
    route_name: str
    route_type: str
    is_direct: bool
    start_sequence: Optional[int] = None
    end_sequence: Optional[int] = None
    distance_meters: Optional[float] = None

class JourneyLeg(BaseModel):
    leg_type: Literal["walk", "bus", "transfer"]
    description: str
    segments: Optional[List[WalkingSegment]] = None
    route: Optional[Union[BusRoute, TransferRoute]] = None

    model_config = {"arbitrary_types_allowed": True} 

class RouteStop(BaseModel):
    sequence: int
    stop_id: int
    stop_name: str
    latitude: float
    longitude: float

class RouteDetails(BaseModel):
    route_id: int
    route_name: str
    route_type: str
    total_distance_meters: float
    estimated_time_seconds: float
    geometry: dict
    stops: List[RouteStop]

class CompleteJourney(BaseModel):
    start_location: LocationPoint
    end_location: LocationPoint

    nearest_start_stops: List[NearestStop]
    nearest_end_stops: List[NearestStop]

    closest_start_stop: NearestStop
    closest_end_stop: NearestStop

    direct_routes: List[BusRoute] = []
    transfer_routes: List[TransferRoute] = []
    has_direct_route: bool

    walking_to_start: Optional[List[WalkingSegment]] = None
    walking_from_end: Optional[List[WalkingSegment]] = None

    journey_legs: List[JourneyLeg] = []
