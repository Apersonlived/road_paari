from sqlalchemy import Column, Integer, BigInteger, String, Text, Boolean, ForeignKey, Float
from sqlalchemy.orm import relationship
from geoalchemy2 import Geometry
from app.core.database import Base

class OSMNode(Base):
    __tablename__ = "osm_node"

    osm_id = Column(BigInteger, primary_key=True)
    name = Column(Text)
    is_stop = Column(Boolean, default=False)
    geom = Column(Geometry("POINT", srid=4326))

class OSMWay(Base):
    __tablename__ = "osm_way"

    osm_id = Column(BigInteger, primary_key=True)
    name = Column(Text)
    highway_type = Column(Text)
    geom = Column(Geometry("LINESTRING", srid=4326))
    
    # pgRouting columns
    source = Column(Integer, index=True)
    target = Column(Integer, index=True)
    cost = Column(Float)
    reverse_cost = Column(Float)
    
    # Additional columns for multi-modal routing
    length_meters = Column(Float)
    
    is_routable  = Column(Boolean, default=True)
    is_oneway    = Column(Boolean, default=False)
    foot_access  = Column(Text)
    surface      = Column(Text) 

class Route(Base):
    __tablename__ = "route"

    route_id = Column(BigInteger, primary_key=True)
    route_name = Column(Text)
    route_type = Column(Text)
    geom = Column(Geometry("MULTILINESTRING", srid=4326))
    direction  = Column(Text)

class RouteWay(Base):
    __tablename__ = "route_way"

    route_id = Column(BigInteger, ForeignKey("route.route_id"), primary_key=True)
    way_id = Column(BigInteger, ForeignKey("osm_way.osm_id"), primary_key=True)
    sequence = Column(Integer)

class BusStop(Base):
    __tablename__ = "bus_stop"

    stop_id = Column(BigInteger, primary_key=True)
    name = Column(Text)
    geom = Column(Geometry("POINT", srid=4326))
    
class RouteStop(Base):
    __tablename__ = "route_stop"
    route_id = Column(BigInteger, ForeignKey("route.route_id", ondelete="CASCADE"), primary_key=True)
    stop_id  = Column(BigInteger, ForeignKey("bus_stop.stop_id"), primary_key=True)
    sequence = Column(Integer)
