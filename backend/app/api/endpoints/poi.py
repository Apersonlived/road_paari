from fastapi import APIRouter, Depends, Query, UploadFile, File
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import Optional
from app.core.database import get_db
from app.core.security import get_current_user
from app.schemas.poi import POI, POICreate, POIUpdate, POICategory, POICategoryCreate
from app.crud import poi as poi_crud

router = APIRouter()

# ── POI image upload ──────────────────────────────────────────────────────────
@router.patch("/{poi_id}/image", response_model=POI)
def upload_poi_image(
    poi_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    return poi_crud.update_poi_image(db, poi_id, file)


@router.delete("/{poi_id}/image", response_model=POI)
def remove_poi_image(
    poi_id: int,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    return poi_crud.delete_poi_image(db, poi_id)

# ── Category icon upload ──────────────────────────────────────────────────────
@router.patch("/categories/{category_id}/icon", response_model=POICategory)
def upload_category_icon(
    category_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    return poi_crud.update_category_icon(db, category_id, file)

# ── Category endpoints ────────────────────────────────────────────────────────

@router.post("/categories", response_model=POICategory)
def create_category(
    category_in: POICategoryCreate,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),  # protected
):
    return poi_crud.create_category(db, category_in)

@router.get("/categories", response_model=list[POICategory])
def list_categories(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
):
    return poi_crud.get_categories(db, skip=skip, limit=limit)

@router.delete("/categories/{category_id}")
def delete_category(
    category_id: int,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),  # protected
):
    return poi_crud.delete_category(db, category_id)

# ── POI endpoints ─────────────────────────────────────────────────────────────
@router.post("/", response_model=POI)
def create_poi(
    poi_in: POICreate,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),  # protected
):
    return poi_crud.create_poi(db, poi_in)


@router.get("/", response_model=list[POI])
def list_pois(
    skip: int = 0,
    limit: int = 100,
    category_id: Optional[int] = None,
    db: Session = Depends(get_db),
):
    return poi_crud.get_pois(db, skip=skip, limit=limit, category_id=category_id)

@router.get("/nearby", response_model=list[dict])
def get_nearby_pois(
    lat: float = Query(..., description="Latitude"),
    lng: float = Query(..., description="Longitude"),
    radius: float = Query(1000, description="Radius in meters"),
    category_id: Optional[int] = None,
    limit: int = 20,
    db: Session = Depends(get_db),
):
    return poi_crud.get_pois_near_location(
        db, lat=lat, lng=lng,
        radius_meters=radius,
        category_id=category_id,
        limit=limit,
    )

@router.get("/search", response_model=list[POI])
def search_pois(
    name: str = Query(..., description="Search term"),
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
):
    return poi_crud.search_pois_by_name(db, name=name, skip=skip, limit=limit)

@router.get("/{poi_id}", response_model=POI)
def get_poi(poi_id: int, db: Session = Depends(get_db)):
    return poi_crud.get_poi(db, poi_id)

@router.patch("/{poi_id}", response_model=POI)
def update_poi(
    poi_id: int,
    poi_in: POIUpdate,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),  # protected
):
    return poi_crud.update_poi(db, poi_id, poi_in)


@router.delete("/{poi_id}")
def delete_poi(
    poi_id: int,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),  # protected
):
    return poi_crud.delete_poi(db, poi_id)