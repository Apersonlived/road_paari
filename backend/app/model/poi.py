from sqlalchemy import Column, Integer, BigInteger, String, Text, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from geoalchemy2 import Geometry
from database import Base

class POICategory(Base):
    __tablename__ = "poi_category"

    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    description = Column(Text)

class POI(Base):
    __tablename__ = "poi"

    id = Column(Integer, primary_key=True)
    name = Column(String(150), nullable=False)
    description = Column(Text)
    category_id = Column(Integer, ForeignKey("poi_category.id"))
    geom = Column(Geometry("POINT", srid=4326))

