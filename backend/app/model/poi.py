from sqlalchemy import Column, Integer, String, Text, ForeignKey, DateTime
from sqlalchemy.sql import func
from geoalchemy2 import Geometry
from app.core.database import Base


class POICategory(Base):
    __tablename__ = "poi_category"

    id          = Column(Integer, primary_key=True)
    name        = Column(String(100), nullable=False)
    description = Column(Text)
    icon        = Column(String(255), nullable=True)


class POI(Base):
    __tablename__ = "poi"

    id          = Column(Integer, primary_key=True)
    name        = Column(String(150), nullable=False)
    description = Column(Text)
    category_id = Column(Integer, ForeignKey("poi_category.id"))
    geom        = Column(Geometry("POINT", srid=4326))
    image_url   = Column(String(500), nullable=True)
    created_at  = Column(DateTime(timezone=True), server_default=func.now())
    created_by  = Column(Integer, ForeignKey("app_user.id"), nullable=True)