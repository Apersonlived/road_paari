from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List, Optional
from pydantic import BaseModel
from app.core.database import get_db
import json

router = APIRouter()

# Pydantic Models
class LocationPoint(BaseModel):
    lat: float
    lng: float

class NearestStop(BaseModel):
    stop_id: int
    stop_name: Optional[str]
    distance_meters: float
    latitude: float
    longitude: float

class BusRoute(BaseModel):
    route_id: int
    route_name: str
    route_type: str
    is_direct: bool
    start_sequence: Optional[int]
    end_sequence: Optional[int]
    distance_meters: Optional[float]

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
    geometry: dict  # GeoJSON type
    stops: List[RouteStop]

class WalkingSegment(BaseModel):
    seq: int
    way_id: Optional[int]
    way_name: Optional[str]
    length_meters: Optional[float]
    cost: float
    geometry: dict  # GeoJSON type

class CompleteJourney(BaseModel):
    start_location: LocationPoint
    end_location: LocationPoint
    nearest_start_stops: List[NearestStop]
    nearest_end_stops: List[NearestStop]
    direct_routes: List[BusRoute]
    has_direct_route: bool
    walking_to_start: Optional[List[WalkingSegment]] = None
    walking_from_end: Optional[List[WalkingSegment]] = None

# Endpoints
@router.get("/nearest-stops", response_model=List[NearestStop])
async def get_nearest_stops(
    lat: float = Query(..., description="Latitude"),
    lng: float = Query(..., description="Longitude"),
    max_distance: int = Query(500, description="Max distance in meters"),
    limit: int = Query(5, description="Number of stops to return"),
    db: Session = Depends(get_db)
):
    """
    Find nearest bus stops to a location
    """
    try:
        query = text("""
            SELECT * FROM find_nearest_stops(:lat, :lng, :max_dist, :lim)
        """)
        
        results = db.execute(
            query,
            {"lat": lat, "lng": lng, "max_dist": max_distance, "lim": limit}
        ).fetchall()
        
        return [
            NearestStop(
                stop_id=row[0],
                stop_name=row[1],
                distance_meters=row[2],
                latitude=row[3],
                longitude=row[4]
            )
            for row in results
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/routes-between-stops", response_model=List[BusRoute])
async def get_routes_between_stops(
    start_stop_id: int = Query(..., description="Start bus stop ID"),
    end_stop_id: int = Query(..., description="End bus stop ID"),
    db: Session = Depends(get_db)
):
    """
    Find all bus routes that connect two stops
    """
    try:
        query = text("""
            SELECT * FROM find_routes_between_stops(:start, :end)
        """)
        
        results = db.execute(
            query,
            {"start": start_stop_id, "end": end_stop_id}
        ).fetchall()
        
        if not results:
            raise HTTPException(
                status_code=404,
                detail=f"No routes found between stop {start_stop_id} and {end_stop_id}"
            )
        
        return [
            BusRoute(
                route_id=row[0],
                route_name=row[1],
                route_type=row[2],
                is_direct=row[3],
                start_sequence=row[4],
                end_sequence=row[5],
                distance_meters=row[6]
            )
            for row in results
        ]
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/route-details/{route_id}", response_model=RouteDetails)
async def get_route_details(
    route_id: int,
    start_stop_id: Optional[int] = Query(None, description="Starting stop ID"),
    end_stop_id: Optional[int] = Query(None, description="Ending stop ID"),
    db: Session = Depends(get_db)
):
    """
    Get detailed information about a specific route
    """
    try:
        query = text("""
            SELECT * FROM get_route_geometry(:route_id, :start_stop, :end_stop)
        """)
        
        result = db.execute(
            query,
            {
                "route_id": route_id,
                "start_stop": start_stop_id,
                "end_stop": end_stop_id
            }
        ).fetchone()
        
        if not result:
            raise HTTPException(
                status_code=404,
                detail=f"Route {route_id} not found"
            )
        
        # Parse stops JSON
        stops_data = result[6]  # stops column
        stops = []
        if stops_data:
            for stop in stops_data:
                stops.append(RouteStop(
                    sequence=stop['sequence'],
                    stop_id=stop['stop_id'],
                    stop_name=stop['stop_name'],
                    latitude=stop['latitude'],
                    longitude=stop['longitude']
                ))
        
        return RouteDetails(
            route_id=result[0],
            route_name=result[1],
            route_type=result[2],
            total_distance_meters=result[3],
            estimated_time_seconds=result[4],
            geometry=json.loads(result[5]),  # geom_json
            stops=stops
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/plan-journey", response_model=CompleteJourney)
async def plan_journey(
    start: LocationPoint,
    end: LocationPoint,
    max_walk_distance: int = Query(500, description="Max walking distance in meters"),
    db: Session = Depends(get_db)
):
    """
    Plan complete journey from start to end location
    Includes:
    - Nearest stops to start and end
    - Direct bus routes between stops
    - Walking routes if needed
    """
    try:
        query = text("""
            SELECT find_complete_journey(:start_lat, :start_lng, :end_lat, :end_lng, :max_walk)
        """)
        
        result = db.execute(
            query,
            {
                "start_lat": start.lat,
                "start_lng": start.lng,
                "end_lat": end.lat,
                "end_lng": end.lng,
                "max_walk": max_walk_distance
            }
        ).fetchone()
        
        if not result or not result[0]:
            raise HTTPException(
                status_code=404,
                detail="Could not plan journey"
            )
        
        journey_data = result[0]
        
        # Parse response
        nearest_start = [
            NearestStop(**stop) for stop in journey_data.get('nearest_start_stops', [])
        ] if journey_data.get('nearest_start_stops') else []
        
        nearest_end = [
            NearestStop(**stop) for stop in journey_data.get('nearest_end_stops', [])
        ] if journey_data.get('nearest_end_stops') else []
        
        direct_routes = [
            BusRoute(**route) for route in journey_data.get('direct_routes', [])
        ] if journey_data.get('direct_routes') else []
        
        # Calculate walking segments if needed
        walking_to_start = None
        walking_from_end = None
        
        if nearest_start:
            walk_query = text("""
                SELECT * FROM calculate_walking_route(:s_lat, :s_lng, :e_lat, :e_lng)
            """)
            
            walk_result = db.execute(
                walk_query,
                {
                    "s_lat": start.lat,
                    "s_lng": start.lng,
                    "e_lat": nearest_start[0].latitude,
                    "e_lng": nearest_start[0].longitude
                }
            ).fetchall()
            
            if walk_result:
                walking_to_start = [
                    WalkingSegment(
                        seq=row[0],
                        way_id=row[1],
                        way_name=row[2],
                        length_meters=row[3],
                        cost=row[4],
                        geometry=json.loads(row[5]) if row[5] else {}
                    )
                    for row in walk_result
                ]
        
        return CompleteJourney(
            start_location=start,
            end_location=end,
            nearest_start_stops=nearest_start,
            nearest_end_stops=nearest_end,
            direct_routes=direct_routes,
            has_direct_route=journey_data.get('has_direct_route', False),
            walking_to_start=walking_to_start,
            walking_from_end=walking_from_end
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/routes-at-stop/{stop_id}")
async def get_routes_at_stop(
    stop_id: int,
    db: Session = Depends(get_db)
):
    """
    Get all bus routes that serve a specific stop
    """
    try:
        query = text("""
            SELECT * FROM get_routes_at_stop(:stop_id)
        """)
        
        results = db.execute(query, {"stop_id": stop_id}).fetchall()
        
        if not results:
            raise HTTPException(
                status_code=404,
                detail=f"No routes found for stop {stop_id}"
            )
        
        return [
            {
                "route_id": row[0],
                "route_name": row[1],
                "route_type": row[2],
                "stop_sequence": row[3]
            }
            for row in results
        ]
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/route-types")
async def get_available_route_types(db: Session = Depends(get_db)):
    """
    Get all available route types (bus, minibus, microbus, etc.)
    """
    try:
        query = text("SELECT DISTINCT route_type FROM route WHERE route_type IS NOT NULL")
        results = db.execute(query).fetchall()
        
        return {
            "route_types": [row[0] for row in results if row[0]]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "ok",
        "service": "routing",
        "features": [
            "nearest_stops",
            "routes_between_stops",
            "route_details",
            "plan_journey",
            "walking_routes"
        ]
    }