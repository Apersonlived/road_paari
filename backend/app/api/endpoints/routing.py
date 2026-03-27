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
async def get_nearest_stops(
    lat: float = Query(..., description="Latitude"),
    lng: float = Query(..., description="Longitude"),
    max_distance: int = Query(500, description="Max distance in meters"),
    limit: int = Query(5, description="Number of stops to return"),
    db: Session = Depends(get_db)
):
    """Find nearest bus stops to a location"""
    try:
        results = db.execute(
            text("SELECT * FROM find_nearest_stops(:lat, :lng, :max_dist, :lim)"),
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
        raise HTTPException(status_code=500, detail=f"nearest-stops error: {str(e)}")


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
        raise HTTPException(status_code=500, detail=f"route-details error: {str(e)}")


@router.post("/plan-journey", response_model=CompleteJourney)
async def plan_journey(
    start: LocationPoint,
    end: LocationPoint,
    max_walk_distance: int = Query(500, description="Max walking distance in meters"),
    db: Session = Depends(get_db)
):
    """
    Plan complete journey from start to end location.
    Uses closest stops only, finds direct + transfer routes,
    and assembles a full end-to-end journey with walking segments.
    """
    try:
        # ── Step 1: Find nearest stops to start and end ───────────────────────
        start_stops_result = db.execute(
            text("SELECT * FROM find_nearest_stops(:lat, :lng, :max_dist, :lim)"),
            {"lat": start.lat, "lng": start.lng, "max_dist": max_walk_distance, "lim": 3}
        ).fetchall()

        end_stops_result = db.execute(
            text("SELECT * FROM find_nearest_stops(:lat, :lng, :max_dist, :lim)"),
            {"lat": end.lat, "lng": end.lng, "max_dist": max_walk_distance, "lim": 3}
        ).fetchall()

        nearest_start = [
            NearestStop(
                stop_id=row[0], stop_name=row[1],
                distance_meters=row[2], latitude=row[3], longitude=row[4]
            )
            for row in start_stops_result
        ]

        nearest_end = [
            NearestStop(
                stop_id=row[0], stop_name=row[1],
                distance_meters=row[2], latitude=row[3], longitude=row[4]
            )
            for row in end_stops_result
        ]

        if not nearest_start or not nearest_end:
            raise HTTPException(
                status_code=404,
                detail="No bus stops found near start or end location. "
                       "Try increasing max_walk_distance."
            )

        # ── Step 2: Use only the closest stop on each side ────────────────────
        closest_start = nearest_start[0]
        closest_end = nearest_end[0]

        # ── Step 3: Find direct routes between the closest stop pair ──────────
        direct_routes = []
        has_direct = False

        try:
            routes_result = db.execute(
                text("SELECT * FROM find_routes_between_stops(:start, :end)"),
                {"start": closest_start.stop_id, "end": closest_end.stop_id}
            ).fetchall()

            for row in routes_result:
                route = BusRoute(
                    route_id=row[0],
                    route_name=row[1],
                    route_type=row[2],
                    is_direct=row[3],
                    start_sequence=row[4],
                    end_sequence=row[5],
                    distance_meters=row[6]
                )
                direct_routes.append(route)
                if row[3]:  # is_direct
                    has_direct = True
        except Exception:
            pass  # No direct routes found try transfers

        # ── Step 4: Find transfer routes if no direct route exists ────────────
        transfer_routes = []
        if not has_direct:
            try:
                # Find routes FROM the start stop, then routes TO the end stop,
                # and match on a shared intermediate stop
                outbound_result = db.execute(
                    text("SELECT * FROM find_routes_from_stop(:stop_id)"),
                    {"stop_id": closest_start.stop_id}
                ).fetchall()

                inbound_result = db.execute(
                    text("SELECT * FROM find_routes_from_stop(:stop_id)"),
                    {"stop_id": closest_end.stop_id}
                ).fetchall()

                # Index inbound routes by the stops they serve
                inbound_stops = {}
                for row in inbound_result:
                    stop_id = row[1]  # intermediate stop_id
                    if stop_id not in inbound_stops:
                        inbound_stops[stop_id] = []
                    inbound_stops[stop_id].append(row)

                # Find outbound routes that share a stop with an inbound route
                for out_row in outbound_result:
                    transfer_stop_id = out_row[1]
                    if transfer_stop_id in inbound_stops:
                        for in_row in inbound_stops[transfer_stop_id]:
                            transfer = TransferRoute(
                                first_route_id=out_row[0],
                                first_route_name=out_row[2],
                                transfer_stop_id=transfer_stop_id,
                                transfer_stop_name=out_row[3],
                                second_route_id=in_row[0],
                                second_route_name=in_row[2],
                            )
                            # Avoid duplicates
                            if not any(
                                t.first_route_id == transfer.first_route_id
                                and t.second_route_id == transfer.second_route_id
                                for t in transfer_routes
                            ):
                                transfer_routes.append(transfer)
            except Exception as transfer_err:
                print(f"Transfer route search failed: {transfer_err}")

        # ── Step 5: Walking to nearest start stop ─────────────────────────────
        walking_to_start = None
        try:
            walk_result = db.execute(
                text("""
                    SELECT * FROM calculate_walking_route(
                        :s_lat, :s_lng, :e_lat, :e_lng
                    )
                """),
                {
                    "s_lat": start.lat, "s_lng": start.lng,
                    "e_lat": closest_start.latitude,
                    "e_lng": closest_start.longitude
                }
            ).fetchall()

            if walk_result:
                walking_to_start = [
                    WalkingSegment(
                        seq=row[0], way_id=row[1], way_name=row[2],
                        length_meters=row[3], cost=row[4],
                        geometry=_parse_geometry(row[5])
                    )
                    for row in walk_result
                ]
        except Exception as walk_err:
            print(f"Walking to start failed: {walk_err}")

        # ── Step 6: Walking from nearest end stop ─────────────────────────────
        walking_from_end = None
        try:
            walk_result = db.execute(
                text("""
                    SELECT * FROM calculate_walking_route(
                        :s_lat, :s_lng, :e_lat, :e_lng
                    )
                """),
                {
                    "s_lat": closest_end.latitude,
                    "s_lng": closest_end.longitude,
                    "e_lat": end.lat, "e_lng": end.lng,
                }
            ).fetchall()

            if walk_result:
                walking_from_end = [
                    WalkingSegment(
                        seq=row[0], way_id=row[1], way_name=row[2],
                        length_meters=row[3], cost=row[4],
                        geometry=_parse_geometry(row[5])
                    )
                    for row in walk_result
                ]
        except Exception as walk_err:
            print(f"Walking from end failed: {walk_err}")

        # ── Step 7: Assemble the full end-to-end journey ──────────────────────
        journey_legs = []

        if walking_to_start:
            journey_legs.append(JourneyLeg(
                leg_type="walk",
                description=f"Walk to {closest_start.stop_name}",
                segments=walking_to_start,
                route=None
            ))

        if direct_routes:
            journey_legs.append(JourneyLeg(
                leg_type="bus",
                description=f"Bus from {closest_start.stop_name} to {closest_end.stop_name}",
                segments=None,
                route=direct_routes[0]  # Best direct route
            ))
        elif transfer_routes:
            first_transfer = transfer_routes[0]
            journey_legs.append(JourneyLeg(
                leg_type="bus",
                description=f"Bus ({first_transfer.first_route_name}) to {first_transfer.transfer_stop_name}",
                segments=None,
                route=first_transfer
            ))
            journey_legs.append(JourneyLeg(
                leg_type="transfer",
                description=f"Transfer at {first_transfer.transfer_stop_name}",
                segments=None,
                route=None
            ))
            journey_legs.append(JourneyLeg(
                leg_type="bus",
                description=f"Bus ({first_transfer.second_route_name}) to {closest_end.stop_name}",
                segments=None,
                route=first_transfer
            ))

        if walking_from_end:
            journey_legs.append(JourneyLeg(
                leg_type="walk",
                description=f"Walk from {closest_end.stop_name} to destination",
                segments=walking_from_end,
                route=None
            ))

        return CompleteJourney(
            start_location=start,
            end_location=end,
            nearest_start_stops=nearest_start,
            nearest_end_stops=nearest_end,
            closest_start_stop=closest_start,
            closest_end_stop=closest_end,
            direct_routes=direct_routes,
            transfer_routes=transfer_routes,
            has_direct_route=has_direct,
            walking_to_start=walking_to_start,
            walking_from_end=walking_from_end,
            journey_legs=journey_legs
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"plan-journey error: {str(e)}")

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