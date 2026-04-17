from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List, Optional
from app.core.database import get_db
from app.schemas.routing import (
    LocationPoint, NearestStop, BusRoute, RouteDetails, RouteStop, StopInfo,
    WalkingSegment, CompleteJourney, TransferRoute, JourneyLeg
)
import json
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

# Helper Functions
def _parse_geometry(geom_data) -> dict:
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


async def _get_bus_leg_details(
    db: Session,
    route_id: int,
    start_stop_id: int,
    end_stop_id: int
) -> BusRoute:
    """Get accurate per-leg bus data using get_route_geometry"""
    try:
        result = db.execute(
            text("""
                SELECT * FROM get_route_geometry(:route_id, :start_stop, :end_stop)
            """),
            {"route_id": route_id, "start_stop": start_stop_id, "end_stop": end_stop_id}
        ).fetchone()

        if not result:
            raise HTTPException(status_code=500, detail="Failed to get leg details")

        return BusRoute(
            route_id=result[0],
            route_name=result[1] or "",
            route_type=result[2] or "bus",
            is_direct=True,
            distance_meters=float(result[8] or result[3] or 0),
            fare_nrs=float(result[5] or 0),
            estimated_time_seconds=float(result[4] or 0),
        )
    except Exception as e:
        logger.error(f"Failed to get bus leg details for route {route_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get leg details")

def _walking_distance(segments: list) -> float:
    """Sum walking distance, falling back to cost*1.4 when length_meters is None."""
    total = 0.0
    for s in segments:
        if s.length_meters and s.length_meters > 0:
            total += s.length_meters
        elif s.cost and s.cost > 0:
            total += s.cost * 1.4  # 1.4 m/s walking speed
    return total


async def _get_stop_info(db: Session, stop_id: int) -> Optional[StopInfo]:
    """Fetch stop name and coordinates for a given stop_id."""
    try:
        row = db.execute(
            text("SELECT stop_id, name, ST_Y(geom) as lat, ST_X(geom) as lng FROM bus_stop WHERE stop_id = :sid"),
            {"sid": stop_id}
        ).fetchone()
        if row:
            return StopInfo(stop_id=row[0], stop_name=row[1], latitude=row[2], longitude=row[3])
    except Exception as e:
        logger.warning(f"Could not fetch stop info for {stop_id}: {e}")
    return None

# Endpoints
@router.get("/nearest-stops", response_model=List[NearestStop])
async def get_nearest_stops(lat: float, lng: float, max_distance: int, limit: int, db: Session = Depends(get_db)):
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
async def find_transfer_routes(start_stop_id: int, end_stop_id: int, db: Session = Depends(get_db)):
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
                total_distance_meters=row[8],
            )
            for row in results
        ]
    except Exception as e:
        logger.warning(f"Transfer route search failed: {str(e)}")
        return []


@router.get("/calculate_walking_segment", response_model=List[WalkingSegment])
async def calculate_walking_segment(start_lat: float, start_lng: float, 
                                  end_lat: float, end_lng: float, 
                                  db: Session = Depends(get_db)):
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


# In get_routes_between_stops - return [] instead of raising, and rollback on error
@router.get("/routes-between-stops", response_model=List[BusRoute])
async def get_routes_between_stops(
    start_stop_id: int = Query(...),
    end_stop_id: int = Query(...),
    db: Session = Depends(get_db)
):
    try:
        results = db.execute(
            text("SELECT * FROM find_routes_between_stops(:start, :end)"),
            {"start": start_stop_id, "end": end_stop_id}
        ).fetchall()

        if not results:
            return []  # ← Never raise 404 here

        return [
            BusRoute(
                route_id=row[0],
                route_name=row[1],
                route_type=row[2],
                is_direct=row[3],
                start_sequence=row[4],
                end_sequence=row[5],
                distance_meters=float(row[6]) if len(row) > 6 and row[6] else None,
                fare_nrs=float(row[8]) if len(row) > 8 and row[8] else None,
            )
            for row in results
        ]
    except Exception as e:
        db.rollback()  # ← CRITICAL: reset the poisoned transaction
        logger.warning(f"routes-between-stops error: {e}")
        return []  # ← Return empty instead of raising


# In find_transfer_routes endpoint
@router.get("/transfer-route", response_model=List[TransferRoute])
async def find_transfer_routes(start_stop_id: int, end_stop_id: int, db: Session = Depends(get_db)):
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
                total_distance_meters=row[8],
            )
            for row in results
        ]
    except Exception as e:
        db.rollback()  # ← CRITICAL
        logger.warning(f"Transfer route search failed: {str(e)}")
        return []


# In calculate_walking_segment
@router.get("/calculate_walking_segment", response_model=List[WalkingSegment])
async def calculate_walking_segment(start_lat: float, start_lng: float,
                                  end_lat: float, end_lng: float,
                                  db: Session = Depends(get_db)):
    try:
        results = db.execute(
            text("SELECT * FROM calculate_walking_route(:s_lat, :s_lng, :e_lat, :e_lng)"),
            {"s_lat": start_lat, "s_lng": start_lng, "e_lat": end_lat, "e_lng": end_lng}
        ).fetchall()
        return [
            WalkingSegment(
                seq=row[0], way_id=row[1], way_name=row[2],
                length_meters=row[3], cost=row[4],
                geometry=_parse_geometry(row[5])
            )
            for row in results
        ]
    except Exception as e:
        db.rollback()  # ← CRITICAL
        logger.warning(f"Walking route calculation failed: {str(e)}")
        return []


@router.get("/route-details/{route_id}", response_model=RouteDetails)
async def get_route_details(
    route_id: int,
    start_stop_id: Optional[int] = Query(None),
    end_stop_id: Optional[int] = Query(None),
    db: Session = Depends(get_db)
):
    try:
        result = db.execute(
            text("SELECT * FROM get_route_geometry(:route_id, :start_stop, :end_stop)"),
            {"route_id": route_id, "start_stop": start_stop_id, "end_stop": end_stop_id}
        ).fetchone()

        if not result:
            raise HTTPException(404, f"Route {route_id} not found")

        stops_data = result[7] if len(result) > 7 else None
        stops = []
        if stops_data:
            try:
                if isinstance(stops_data, str):
                    stops_data = json.loads(stops_data)
                if isinstance(stops_data, list):
                    for stop in stops_data:
                        stops.append(RouteStop(
                            sequence=stop.get('sequence'),
                            stop_id=stop.get('stop_id'),
                            stop_name=stop.get('stop_name'),
                            latitude=stop.get('latitude'),
                            longitude=stop.get('longitude')
                        ))
            except Exception as e:
                logger.error(f"Stops parsing error: {e}")

        geom_data = result[6] if len(result) > 6 else None
        geometry = _parse_geometry(geom_data)

        segment_distance = float(result[8] or result[3] or 0) if len(result) > 8 else float(result[3] or 0)

        return RouteDetails(
            route_id=result[0],
            route_name=result[1] or "",
            route_type=result[2] or "",
            total_distance_meters=segment_distance,
            estimated_time_seconds=float(result[4] or 0),
            fare_nrs=float(result[5] or 0),
            geometry=geometry,
            stops=stops
        )
    except Exception as e:
        logger.error(f"route-details error: {e}")
        raise HTTPException(500, f"Failed to get route details: {str(e)}")


# JOURNEY PLANNER 
@router.post("/plan-journey", response_model=CompleteJourney)
async def plan_journey(
    start: LocationPoint,
    end: LocationPoint,
    max_walk_distance: int = Query(1500),
    db: Session = Depends(get_db)
):
    try:
        logger.info(f"Planning journey from {start.lat:.6f},{start.lng:.6f} to {end.lat:.6f},{end.lng:.6f}")

        # Wider search for candidates
        start_candidates = await get_nearest_stops(start.lat, start.lng, max_walk_distance + 800, 20, db)
        end_candidates   = await get_nearest_stops(end.lat, end.lng, max_walk_distance + 800, 20, db)

        logger.info(f"Found {len(start_candidates)} start stops and {len(end_candidates)} end stops")

        if not start_candidates or not end_candidates:
            walking = await calculate_walking_segment(start.lat, start.lng, end.lat, end.lng, db)
            total_walk = sum(s.length_meters or 0 for s in walking)
            return CompleteJourney(
                start_location=start,
                end_location=end,
                journey_legs=[JourneyLeg(
                    leg_type="walk",
                    description="No bus stops nearby - walking entire way",
                    segments=walking,
                    distance_meters=total_walk,
                )],
                error_message="No bus stops found within walking distance."
            )

        # Score pairs 
        scored_pairs = []
        for s in start_candidates:
            for e in end_candidates:
                if s.stop_id == e.stop_id:
                    continue

                walk_cost = s.distance_meters + e.distance_meters

                # Get direct and transfer
                try:
                    direct = await get_routes_between_stops(s.stop_id, e.stop_id, db) if s.stop_id != e.stop_id else []
                except Exception:
                    db.rollback()
                    direct = []

                transfers = []
                if not direct:
                    try:
                        transfers = await find_transfer_routes(s.stop_id, e.stop_id, db)
                    except Exception:
                        db.rollback()
                        transfers = []

                if direct:
                    best_d = min(direct, key=lambda r: r.distance_meters or float('inf'))
                    score = walk_cost * 1.0 + (best_d.distance_meters or 0) * 0.6   # strongly prefer bus
                    is_direct = True
                elif transfers:
                    best_t = min(transfers, key=lambda t: (t.total_stop_count or 999, t.transfer_walk_meters or 9999))
                    score = walk_cost * 1.0 + (best_t.total_distance_meters or 0) + (best_t.transfer_walk_meters or 0) * 1.0
                    is_direct = False
                else:
                    score = walk_cost + 999999
                    is_direct = False

                scored_pairs.append({
                    "start_stop": s,
                    "end_stop": e,
                    "total_score": score,
                    "is_direct": is_direct,
                    "direct_routes": direct,
                    "transfer_routes": transfers,
                })

        # If best score is still very high → fallback to walking
        if not scored_pairs or scored_pairs[0]["total_score"] > 100000:
            walking = await calculate_walking_segment(start.lat, start.lng, end.lat, end.lng, db)
            total_walk = sum(s.length_meters or 0 for s in walking)
            return CompleteJourney(
                start_location=start,
                end_location=end,
                nearest_start_stops=start_candidates[:8],
                nearest_end_stops=end_candidates[:8],
                journey_legs=[JourneyLeg(
                    leg_type="walk",
                    description="No bus connection found - walking the entire distance",
                    segments=walking,
                    distance_meters=total_walk,
                )],
                error_message="No bus route found between these locations. Pure walking provided."
            )

        # Use best pair
        scored_pairs.sort(key=lambda x: x["total_score"])
        best = scored_pairs[0]

        s_stop = best["start_stop"]
        e_stop = best["end_stop"]

        # Walking segments
        walking_to_start = []
        try:
            walking_to_start = await calculate_walking_segment(start.lat, start.lng, s_stop.latitude, s_stop.longitude, db)
        except Exception as ex:
            logger.warning(f"Walking to start failed: {ex}")

        walking_from_end = []
        try:
            walking_from_end = await calculate_walking_segment(e_stop.latitude, e_stop.longitude, end.lat, end.lng, db)
        except Exception as ex:
            logger.warning(f"Walking from end failed: {ex}")

        journey_legs: List[JourneyLeg] = []
        total_fare = 0.0
        total_dist = 0.0

        # Walk to bus stop
        if walking_to_start:
            walk_dist = _walking_distance(walking_to_start)  # ← use helper
            journey_legs.append(JourneyLeg(
                leg_type="walk",
                description=f"Walk to {s_stop.stop_name or 'bus stop'}",
                segments=walking_to_start,
                distance_meters=walk_dist,
                alight_stop=StopInfo(
                    stop_id=s_stop.stop_id,
                    stop_name=s_stop.stop_name,
                    latitude=s_stop.latitude,
                    longitude=s_stop.longitude,
                ),
            ))
            total_dist += walk_dist

        # Direct bus leg
        if best["is_direct"] and best["direct_routes"]:
            best_route = min(best["direct_routes"], key=lambda r: r.distance_meters or float('inf'))
            leg = await _get_bus_leg_details(db, best_route.route_id, s_stop.stop_id, e_stop.stop_id)
            journey_legs.append(JourneyLeg(
                leg_type="bus",
                description=leg.route_name,
                route=leg,
                fare_nrs=leg.fare_nrs,
                distance_meters=leg.distance_meters,
                board_stop=StopInfo(
                    stop_id=s_stop.stop_id,
                    stop_name=s_stop.stop_name,
                    latitude=s_stop.latitude,
                    longitude=s_stop.longitude,
                ),
                alight_stop=StopInfo(
                    stop_id=e_stop.stop_id,
                    stop_name=e_stop.stop_name,
                    latitude=e_stop.latitude,
                    longitude=e_stop.longitude,
                ),
            ))
            total_fare += leg.fare_nrs or 0
            total_dist += leg.distance_meters or 0

        elif best["transfer_routes"]:
            t = min(best["transfer_routes"], key=lambda x: (x.total_stop_count or 999, x.transfer_walk_meters or 9999))
            transfer_stop_info = await _get_stop_info(db, t.transfer_stop_id)

            leg1 = await _get_bus_leg_details(db, t.first_route_id, s_stop.stop_id, t.transfer_stop_id)
            journey_legs.append(JourneyLeg(
                leg_type="bus",
                description=f"{leg1.route_name} → transfer at {t.transfer_stop_name or 'stop'}",
                route=leg1,
                fare_nrs=leg1.fare_nrs,
                distance_meters=leg1.distance_meters,
                board_stop=StopInfo(
                    stop_id=s_stop.stop_id,
                    stop_name=s_stop.stop_name,
                    latitude=s_stop.latitude,
                    longitude=s_stop.longitude,
                ),
                alight_stop=transfer_stop_info,
                transfer_stop=transfer_stop_info,
            ))
            total_fare += leg1.fare_nrs or 0
            total_dist += leg1.distance_meters or 0

            if t.transfer_walk_meters and t.transfer_walk_meters > 30:
                journey_legs.append(JourneyLeg(
                    leg_type="walk",
                    description=f"Transfer walk at {t.transfer_stop_name or 'stop'}",
                    segments=[WalkingSegment(
                        seq=1, way_id=None, way_name="Transfer walk",
                        length_meters=t.transfer_walk_meters,
                        cost=t.transfer_walk_meters / 1.4, geometry={},
                    )],
                    distance_meters=t.transfer_walk_meters,
                ))
                total_dist += t.transfer_walk_meters

            leg2 = await _get_bus_leg_details(db, t.second_route_id, t.transfer_stop_id, e_stop.stop_id)
            journey_legs.append(JourneyLeg(
                leg_type="bus",
                description=leg2.route_name,
                route=leg2,
                fare_nrs=leg2.fare_nrs,
                distance_meters=leg2.distance_meters,
                board_stop=transfer_stop_info,
                alight_stop=StopInfo(
                    stop_id=e_stop.stop_id,
                    stop_name=e_stop.stop_name,
                    latitude=e_stop.latitude,
                    longitude=e_stop.longitude,
                ),
            ))
            total_fare += leg2.fare_nrs or 0
            total_dist += leg2.distance_meters or 0

        # Final walk
        if walking_from_end:
            walk_dist = _walking_distance(walking_from_end)  # ← use helper
            journey_legs.append(JourneyLeg(
                leg_type="walk",
                description=f"Walk to destination from {e_stop.stop_name or 'bus stop'}",
                segments=walking_from_end,
                distance_meters=walk_dist,
                board_stop=StopInfo(
                    stop_id=e_stop.stop_id,
                    stop_name=e_stop.stop_name,
                    latitude=e_stop.latitude,
                    longitude=e_stop.longitude,
                ),
            ))
            total_dist += walk_dist

        return CompleteJourney(
            start_location=start,
            end_location=end,
            nearest_start_stops=start_candidates[:8],
            nearest_end_stops=end_candidates[:8],
            closest_start_stop=s_stop,
            closest_end_stop=e_stop,
            direct_routes=best.get("direct_routes", []),
            transfer_routes=best.get("transfer_routes", []),
            has_direct_route=best.get("is_direct", False),
            walking_to_start=walking_to_start,
            walking_from_end=walking_from_end,
            journey_legs=journey_legs,
            total_fare_nrs=total_fare,
            total_distance_meters=total_dist,
            error_message=None,
        )

    except Exception as e:
        logger.error(f"Journey planning failed: {str(e)}", exc_info=True)
        return CompleteJourney(
            start_location=start,
            end_location=end,
            error_message=f"Planning error: {str(e)}"
        )

# ====================== OTHER ENDPOINTS ======================

@router.get("/routes-at-stop/{stop_id}")
async def get_routes_at_stop(stop_id: int, db: Session = Depends(get_db)):
    try:
        results = db.execute(
            text("SELECT * FROM get_routes_at_stop(:stop_id)"),
            {"stop_id": stop_id}
        ).fetchall()
        return [
            {
                "route_id": row[0],
                "route_name": row[1],
                "route_type": row[2],
                "stop_sequence": row[3]
            }
            for row in results
        ]
    except Exception as e:
        raise HTTPException(500, f"routes-at-stop error: {str(e)}")


@router.get("/health")
async def health_check():
    return {
        "status": "ok",
        "service": "routing",
        "features": ["nearest_stops", "routes_between_stops", "route_details", "plan_journey", "walking_routes"]
    }