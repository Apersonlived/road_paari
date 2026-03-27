from geoalchemy2 import Geometry
from sqlalchemy.orm import Session
from sqlalchemy import func, make_url
from fastapi import HTTPException, status, UploadFile
from geoalchemy2.functions import ST_AsText, ST_Point, ST_DWithin, ST_Distance, ST_SetSRID
from app.model.poi import POI as POIModel, POICategory as POICategoryModel
from app.schemas.poi import POICreate, POIUpdate, POICategoryCreate
import os
import uuid
import shutil

UPLOAD_DIR_POI      = "static/poi_images"
UPLOAD_DIR_ICONS    = "static/category_icons"
ALLOWED_EXTENSIONS  = {".jpg", ".jpeg", ".png", ".webp"}
MAX_FILE_SIZE_MB    = 5

os.makedirs(UPLOAD_DIR_POI, exist_ok=True)
os.makedirs(UPLOAD_DIR_ICONS, exist_ok=True)

def _save_file(file: UploadFile, directory: str, prefix: str) -> str:
    """Validates and saves an uploaded file, returns the URL path."""
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed: {', '.join(ALLOWED_EXTENSIONS)}",
        )
    file.file.seek(0, 2)
    if file.file.tell() > MAX_FILE_SIZE_MB * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Maximum size is {MAX_FILE_SIZE_MB}MB",
        )
    file.file.seek(0)
    filename = f"{prefix}_{uuid.uuid4().hex}{ext}"
    file_path = os.path.join(directory, filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    return f"/{directory}/{filename}"


def _delete_file(url: str) -> None:
    """Deletes a file from disk given its URL path."""
    if url:
        file_path = url.lstrip("/")
        if os.path.exists(file_path):
            os.remove(file_path)

# POI image
def update_poi_image(db: Session, poi_id: int, file: UploadFile) -> POIModel:
    poi = get_poi(db, poi_id)
    _delete_file(poi.image_url)
    poi.image_url = _save_file(file, UPLOAD_DIR_POI, f"poi_{poi_id}")
    db.commit()
    db.refresh(poi)
    return poi

def delete_poi_image(db: Session, poi_id: int) -> POIModel:
    poi = get_poi(db, poi_id)
    if poi.image_url:
        _delete_file(poi.image_url)
        poi.image_url = None
        db.commit()
        db.refresh(poi)
    return poi

# Category icon
def update_category_icon(
    db: Session, category_id: int, file: UploadFile
) -> POICategoryModel:
    category = get_category(db, category_id)
    _delete_file(category.icon)
    category.icon = _save_file(file, UPLOAD_DIR_ICONS, f"cat_{category_id}")
    db.commit()
    db.refresh(category)
    return category

# ── Helper ────────────────────────────────────────────────────────────────────
def _extract_lat_lng(poi: POIModel) -> tuple[float | None, float | None]:
    """
    Extracts latitude and longitude from a POI's geometry column.
    Returns (lat, lng) or (None, None) if no geometry.
    """
    if poi.geom is None:
        return None, None
    # ST_AsText returns 'POINT(lng lat)'
    wkt = poi.geom
    if isinstance(wkt, str) and wkt.startswith("POINT"):
        coords = wkt.replace("POINT(", "").replace(")", "").split()
        return float(coords[1]), float(coords[0])  # lat, lng
    return None, None


def _build_poi_response(poi: POIModel) -> dict:
    """
    Converts a POIModel to a dict with lat/lng extracted from geometry.
    """
    lat, lng = _extract_lat_lng(poi)
    return {
        "id": poi.id,
        "name": poi.name,
        "description": poi.description,
        "category_id": poi.category_id,
        "latitude": lat,
        "longitude": lng,
        "image_url": poi.image_url
    }

# ── Category CRUD ─────────────────────────────────────────────────────────────
def create_category(db: Session, category_in: POICategoryCreate) -> POICategoryModel:
    existing = db.query(POICategoryModel).filter(
        POICategoryModel.name == category_in.name
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Category with this name already exists",
        )
    category = POICategoryModel(
        name=category_in.name,
        description=category_in.description,
    )
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


def get_category(db: Session, category_id: int) -> POICategoryModel:
    category = db.query(POICategoryModel).filter(
        POICategoryModel.id == category_id
    ).first()
    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Category not found",
        )
    return category


def get_categories(
    db: Session, skip: int = 0, limit: int = 100
) -> list[POICategoryModel]:
    return db.query(POICategoryModel).offset(skip).limit(limit).all()


def delete_category(db: Session, category_id: int) -> dict:
    category = get_category(db, category_id)
    db.delete(category)
    db.commit()
    return {"detail": f"Category {category_id} deleted successfully"}


# ── POI CRUD ──────────────────────────────────────────────────────────────────
def create_poi(db: Session, poi_in: POICreate) -> POIModel:
    # Build PostGIS point from lat/lng
    geom = ST_SetSRID(ST_Point(poi_in.longitude, poi_in.latitude), 4326)

    poi = POIModel(
        name=poi_in.name,
        description=poi_in.description,
        category_id=poi_in.category_id,
        geom=geom,
        image_url=poi_in.image_url
    )
    db.add(poi)
    db.commit()

    # Fetch with geometry as WKT for extraction
    poi = db.query(POIModel).filter(POIModel.id == poi.id).first()
    db.refresh(poi)
    return poi


def get_poi(db: Session, poi_id: int) -> POIModel:
    poi = db.query(POIModel).filter(POIModel.id == poi_id).first()
    if not poi:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="POI not found",
        )
    return poi


def get_pois(
    db: Session,
    skip: int = 0,
    limit: int = 100,
    category_id: int | None = None,
) -> list[POIModel]:
    query = db.query(POIModel)
    if category_id is not None:
        query = query.filter(POIModel.category_id == category_id)
    return query.offset(skip).limit(limit).all()


def update_poi(db: Session, poi_id: int, poi_in: POIUpdate) -> POIModel:
    poi = get_poi(db, poi_id)
    update_data = poi_in.model_dump(exclude_unset=True)

    # Handle geometry update if lat/lng provided
    lat = update_data.pop("latitude", None)
    lng = update_data.pop("longitude", None)
    if lat is not None and lng is not None:
        poi.geom = ST_SetSRID(ST_Point(lng, lat), 4326)
    elif lat is not None or lng is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Both latitude and longitude must be provided together",
        )
    
    # Update remaining fields
    for field, value in update_data.items():
        setattr(poi, field, value)

    db.commit()
    db.refresh(poi)
    return poi


def delete_poi(db: Session, poi_id: int) -> dict:
    poi = get_poi(db, poi_id)
    db.delete(poi)
    db.commit()
    return {"detail": f"POI {poi_id} deleted successfully"}


# ── Spatial queries ───────────────────────────────────────────────────────────

def get_pois_near_location(
    db: Session,
    lat: float,
    lng: float,
    radius_meters: float = 1000,
    category_id: int | None = None,
    limit: int = 20,
) -> list[dict]:
    """
    Returns POIs within radius_meters of the given lat/lng,
    sorted by distance ascending. Each result includes distance_meters.
    """
    point = ST_SetSRID(ST_Point(lng, lat), 4326)

    query = db.query(
        POIModel,
        ST_Distance(
            POIModel.geom.cast(Geometry),
            point.cast(Geometry),
        ).label("distance_meters"),
    ).filter(
        ST_DWithin(
            POIModel.geom.cast(Geometry),
            point.cast(Geometry),
            radius_meters / 111320,  # convert meters to degrees (approximate)
        )
    )

    if category_id is not None:
        query = query.filter(POIModel.category_id == category_id)

    results = query.order_by("distance_meters").limit(limit).all()

    pois = []
    for poi, distance in results:
        data = _build_poi_response(poi)
        data["distance_meters"] = round(distance * 111320, 2)
        pois.append(data)

    return pois


def search_pois_by_name(
    db: Session,
    name: str,
    skip: int = 0,
    limit: int = 20,
) -> list[POIModel]:
    """
    Case-insensitive search for POIs by name.
    """
    return (
        db.query(POIModel)
        .filter(POIModel.name.ilike(f"%{name}%"))
        .offset(skip)
        .limit(limit)
        .all()
    )