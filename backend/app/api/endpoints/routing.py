from asyncio.log import logger

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List, Optional
from app.core.database import get_db
from app.schemas.routing import LocationPoint, NearestStop, BusRoute, RouteStop, RouteDetails, WalkingSegment, CompleteJourney, TransferRoute, JourneyLeg
import json

router = APIRouter()

# Helper functions
def _parse_geometry(geom_data) -> dict:
    """
    Parses geometry that may be a JSON string, dict, or None.
    Returns empty GeoJSON if unparseable.
    """
    if geom_data is None:
        return {"type": "LineString", "coordinates": []}
    if isinstance(geom_data, str):
        try:
            return json.loads(geom_data)
        except json.JSONDecodeError:
            return {"type": "LineString", "coordinates": []}
    if isinstance(geom_data, dict):
        return geom_data
    return {"type": "LineString", "coordinates": []}

# Endpoints for routes
@router.get("/nearest-stops", response_model=List[NearestStop])
async def get_nearest_stops(lat: float, lng: float, max_distance: int, limit: int, db: Session = Depends(get_db)) -> List[NearestStop]:
    """Nearest stops finder with distance validation"""
    results = db.execute(
        text("""
            SELECT s.stop_id, s.name, 
                   ST_Distance(s.geom::geography, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography) as distance,
                   ST_Y(s.geom::geometry) as lat, ST_X(s.geom::geometry) as lng
            FROM bus_stop s
            WHERE ST_DWithin(s.geom::geography, 
                            ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                            :max_dist)
            ORDER BY distance
            LIMIT :lim
        """),
        {"lat": lat, "lng": lng, "max_dist": max_distance, "lim": limit}
    ).fetchall()
    
    return [
        NearestStop(
            stop_id=row[0],
            stop_name=row[1],
            distance_meters=float(row[2]),
            latitude=float(row[3]),
            longitude=float(row[4])
        )
        for row in results
    ]

@router.get("/transfer-route", response_model=List[TransferRoute])
async def find_transfer_routes(start_stop_id: int, end_stop_id: int, db: Session = Depends(get_db)) -> List[TransferRoute]:
    """Find transfer routes with proper ranking"""
    try:
        results = db.execute(
            text("SELECT * FROM find_transfer_routes(:start, :end)"),
            {"start": start_stop_id, "end": end_stop_id}
        ).fetchall()
        
        return [
            TransferRoute(
                first_route_id=row[0],
                first_route_name=row[1],
                transfer_stop_id=row[2],
                transfer_stop_name=row[3],
                second_route_id=row[4],
                second_route_name=row[5],
                total_stop_count=row[6],
                transfer_walk_meters=row[7],
                total_distance_meters=row[8]
            )
            for row in results
        ]
    except Exception as e:
        logger.warning(f"Transfer route search failed: {str(e)}")
        return []

@router.get("/calculate_walking_segment", response_model=List[WalkingSegment])
async def calculate_walking_segment(start_lat: float, start_lng: float, 
                                  end_lat: float, end_lng: float, 
                                  db: Session = Depends(get_db)) -> List[WalkingSegment]:
    """Calculate walking route with proper fallbacks"""
    try:
        results = db.execute(
            text("SELECT * FROM calculate_walking_route(:s_lat, :s_lng, :e_lat, :e_lng)"),
            {"s_lat": start_lat, "s_lng": start_lng, "e_lat": end_lat, "e_lng": end_lng}
        ).fetchall()
        
        return [
            WalkingSegment(
                seq=row[0],
                way_id=row[1],
                way_name=row[2],
                length_meters=row[3],
                cost=row[4],
                geometry=_parse_geometry(row[5])
            )
            for row in results
        ]
    except Exception as e:
        logger.warning(f"Walking route calculation failed: {str(e)}")
        return []

@router.get("/routes-between-stops", response_model=List[BusRoute])
async def get_routes_between_stops(
    start_stop_id: int = Query(..., description="Start bus stop ID"),
    end_stop_id: int = Query(..., description="End bus stop ID"),
    db: Session = Depends(get_db)
):
    """Find all bus routes that connect two stops"""
    try:
        results = db.execute(
            text("SELECT * FROM find_routes_between_stops(:start, :end)"),
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
        raise HTTPException(status_code=500, detail=f"routes-between-stops error: {str(e)}")


@router.get("/route-details/{route_id}", response_model=RouteDetails)
async def get_route_details(
    route_id: int,
    start_stop_id: Optional[int] = Query(None),
    end_stop_id: Optional[int] = Query(None),
    db: Session = Depends(get_db)
):
    """Get detailed information about a specific route"""
    try:
        result = db.execute(
            text("SELECT * FROM get_route_geometry(:route_id, :start_stop, :end_stop)"),
            {"route_id": route_id, "start_stop": start_stop_id, "end_stop": end_stop_id}
        ).fetchone()

        if not result:
            raise HTTPException(status_code=404, detail=f"Route {route_id} not found")

        logger.info(f"Route result columns: {result._fields if hasattr(result, '_fields') else 'unknown'}")
        logger.info(f"geom_json preview: {str(result[5])[:100] if result[5] else 'NULL'}")  # ← ADD

        stops_data = result[6]
        stops = []
        if stops_data:
            # stops_data may be a JSON string or already a list
            if isinstance(stops_data, str):
                stops_data = json.loads(stops_data)
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
            geometry=_parse_geometry(result[5]),
            stops=stops
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"route-details error for route {route_id}: {str(e)}", exc_info=True) 
        raise HTTPException(status_code=500, detail=f"route-details error: {str(e)}")

# Plan journey
@router.post("/plan-journey", response_model=CompleteJourney)
async def plan_journey(
    start: LocationPoint,
    end: LocationPoint,
    max_walk_distance: int = Query(500),
    db: Session = Depends(get_db)
):
    try:
        logger.info(f"Planning journey from {start} to {end}")

        start_stops = await get_nearest_stops(start.lat, start.lng, max_walk_distance, 3, db)
        end_stops = await get_nearest_stops(end.lat, end.lng, max_walk_distance, 3, db)

        # Always return nearest stops even if no route found
        base_response = dict(
            start_location=start,
            end_location=end,
            nearest_start_stops=start_stops,
            nearest_end_stops=end_stops,
            closest_start_stop=start_stops[0] if start_stops else None,
            closest_end_stop=end_stops[0] if end_stops else None,
        )

        if not start_stops or not end_stops:
            logger.warning("No stops found within walking distance")
            walking_route = await calculate_walking_segment(
                start.lat, start.lng, end.lat, end.lng, db
            )
            return CompleteJourney(
                **base_response,
                journey_legs=[JourneyLeg(
                    leg_type="walk",
                    description="Walk entire journey (no nearby stops found)",
                    segments=walking_route,
                    route=None
                )],
                error_message="No bus stops found within walking distance"
            )

        # Step 2: Try direct routes across all nearby stop combinations
        direct_routes = []
        for s_stop in start_stops:
            for e_stop in end_stops:
                try:
                    routes = await get_routes_between_stops(s_stop.stop_id, e_stop.stop_id, db)
                    if routes:
                        direct_routes.extend(routes)
                except HTTPException as e:
                    if e.status_code != 404:
                        raise

        # Deduplicate by route_id
        seen = set()
        unique_direct = []
        for r in direct_routes:
            if r.route_id not in seen:
                seen.add(r.route_id)
                unique_direct.append(r)
        direct_routes = unique_direct

        # Step 3: Only search transfers if truly no direct route exists
        transfer_routes = []
        if not direct_routes:
            for s_stop in start_stops:
                for e_stop in end_stops:
                    transfers = await find_transfer_routes(s_stop.stop_id, e_stop.stop_id, db)
                    transfer_routes.extend(transfers)
            # Deduplicate by (first_route_id, second_route_id)
            seen_transfers = set()
            unique_transfers = []
            for t in transfer_routes:
                key = (t.first_route_id, t.second_route_id)
                if key not in seen_transfers:
                    seen_transfers.add(key)
                    unique_transfers.append(t)
            transfer_routes = unique_transfers

        walking_to_start = await calculate_walking_segment(
            start.lat, start.lng,
            start_stops[0].latitude, start_stops[0].longitude,
            db
        )
        walking_from_end = await calculate_walking_segment(
            end_stops[0].latitude, end_stops[0].longitude,
            end.lat, end.lng,
            db
        )

        journey_legs = []

        if walking_to_start:
            journey_legs.append(JourneyLeg(
                leg_type="walk",
                description=f"Walk to {start_stops[0].stop_name} ({len(walking_to_start)} segments)",
                segments=walking_to_start,
                route=None
            ))

        if direct_routes:
            best_route = min(direct_routes, key=lambda r: (
                r.distance_meters or float('inf'),
                (r.end_sequence or 0) - (r.start_sequence or 0)    
            ))
            journey_legs.append(JourneyLeg(
                leg_type="bus",
                description=f"{best_route.route_name} to {end_stops[0].stop_name}",
                segments=None,
                route=best_route
            ))
        elif transfer_routes:
            best_transfer = min(transfer_routes, key=lambda t: (
                t.total_stop_count or 999,
                t.transfer_walk_meters or float('inf')
            ))

            journey_legs.append(JourneyLeg(
                leg_type="bus",
                description=f"{best_transfer.first_route_name} to {best_transfer.transfer_stop_name}",
                segments=None,
                route=BusRoute(
                    route_id=best_transfer.first_route_id,
                    route_name=best_transfer.first_route_name,
                    route_type="bus",
                    is_direct=False,
                    start_sequence=None,
                    end_sequence=None,
                    distance_meters=None
                )
            ))

            if (best_transfer.transfer_walk_meters or 0) > 50:
                journey_legs.append(JourneyLeg(
                    leg_type="walk",
                    description=f"Transfer at {best_transfer.transfer_stop_name}",
                    segments=[WalkingSegment(
                        seq=1,
                        way_id=None,
                        way_name="Transfer path",
                        length_meters=best_transfer.transfer_walk_meters,
                        cost=(best_transfer.transfer_walk_meters or 0) / 1.4,
                        geometry={"type": "LineString", "coordinates": []}
                    )],
                    route=None
                ))

            journey_legs.append(JourneyLeg(
                leg_type="bus",
                description=f"{best_transfer.second_route_name} to {end_stops[0].stop_name}",
                segments=None,
                route=BusRoute(
                    route_id=best_transfer.second_route_id,
                    route_name=best_transfer.second_route_name,
                    route_type="bus",
                    is_direct=False,
                    start_sequence=None,
                    end_sequence=None,
                    distance_meters=None
                )
            ))
        else:
            # No transit found — still return stop info + walking
            journey_legs.append(JourneyLeg(
                leg_type="walk",
                description="No bus route found, walking entire journey",
                segments=await calculate_walking_segment(
                    start.lat, start.lng, end.lat, end.lng, db
                ),
                route=None
            ))

        if walking_from_end:
            journey_legs.append(JourneyLeg(
                leg_type="walk",
                description=f"Walk from {end_stops[0].stop_name} to destination",
                segments=walking_from_end,
                route=None
            ))

        return CompleteJourney(
            **base_response,
            direct_routes=direct_routes,
            transfer_routes=transfer_routes,
            has_direct_route=bool(direct_routes),
            walking_to_start=walking_to_start,
            walking_from_end=walking_from_end,
            journey_legs=journey_legs
        )

    except Exception as e:
        logger.error(f"Journey planning failed: {str(e)}", exc_info=True)
        # ← Return partial data instead of a bare 500
        return CompleteJourney(
            start_location=start,
            end_location=end,
            error_message=f"Journey planning failed: {str(e)}"
        )

@router.get("/routes-at-stop/{stop_id}")
async def get_routes_at_stop(
    stop_id: int,
    db: Session = Depends(get_db)
):
    """Get all bus routes that serve a specific stop"""
    try:
        results = db.execute(
            text("SELECT * FROM get_routes_at_stop(:stop_id)"),
            {"stop_id": stop_id}
        ).fetchall()

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
        raise HTTPException(status_code=500, detail=f"routes-at-stop error: {str(e)}")


@router.get("/route-types")
async def get_available_route_types(db: Session = Depends(get_db)):
    """Get all available route types"""
    try:
        results = db.execute(
            text("SELECT DISTINCT route_type FROM route WHERE route_type IS NOT NULL")
        ).fetchall()
        return {"route_types": [row[0] for row in results if row[0]]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/route-info/{route_id}")
async def get_route_info(
    route_id: int,
    db: Session = Depends(get_db)
):
    """Get route metadata including direction and type"""
    try:
        result = db.execute(
            text("""
                SELECT 
                    r.route_id,
                    r.route_name,
                    r.route_type,
                    r.direction,
                    COUNT(rs.stop_id) as stop_count,
                    ST_Length(r.geom::geography) as total_distance_meters
                FROM route r
                LEFT JOIN route_stop rs ON rs.route_id = r.route_id
                WHERE r.route_id = :route_id
                GROUP BY r.route_id, r.route_name, r.route_type, 
                         r.direction, r.geom
            """),
            {"route_id": route_id}
        ).fetchone()

        if not result:
            raise HTTPException(
                status_code=404, 
                detail=f"Route {route_id} not found"
            )

        return {
            "route_id":              result[0],
            "route_name":            result[1],
            "route_type":            result[2],
            "direction":             result[3],
            "stop_count":            result[4],
            "total_distance_meters": result[5]
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/way-info/{way_id}")
async def get_way_info(
    way_id: int,
    db: Session = Depends(get_db)
):
    """Get way metadata including oneway, foot access, surface"""
    try:
        result = db.execute(
            text("""
                SELECT 
                    osm_id,
                    name,
                    highway_type,
                    is_oneway,
                    foot_access,
                    surface,
                    length_meters
                FROM osm_way
                WHERE osm_id = :way_id
            """),
            {"way_id": way_id}
        ).fetchone()

        if not result:
            raise HTTPException(
                status_code=404, 
                detail=f"Way {way_id} not found"
            )

        return {
            "way_id":        result[0],
            "name":          result[1],
            "highway_type":  result[2],
            "is_oneway":     result[3],
            "foot_access":   result[4],
            "surface":       result[5],
            "length_meters": result[6]
        }
    except HTTPException:
        raise
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