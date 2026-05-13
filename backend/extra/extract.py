from lxml import etree
from shapely.geometry import Point, LineString, MultiLineString
from geoalchemy2.shape import from_shape
import sys
from pathlib import Path
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Path setup 
current_file = Path(__file__).resolve()
backend_dir  = current_file.parent.parent 
project_dir  = backend_dir.parent 

sys.path.insert(0, str(project_dir))
sys.path.insert(0, str(backend_dir)) 

# Read from .env manually to avoid triggering pydantic Settings
from dotenv import dotenv_values

env_path = backend_dir / ".env"

config   = dotenv_values(str(env_path))
DB_URL   = config.get("DATABASE_URL")

if not DB_URL:
    print("✗ DATABASE_URL not found in .env")
    sys.exit(1)

print(f"✓ Connecting to: {DB_URL[:40]}...")

engine       = create_engine(DB_URL, echo=False, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)

from app.model.transport import OSMNode, OSMWay, Route, RouteWay, BusStop, RouteStop

def import_osm(xml_file):
    session = SessionLocal()
    try:
        print(f"Parsing XML file: {xml_file}")
        tree = etree.parse(xml_file)
        root = tree.getroot()

        nodes_dict = {}
        stops_dict = {}

        # Step 1: Nodes 
        print("Processing nodes...")
        node_count = 0
        stop_count = 0

        for node in root.findall("node"):
            osm_id = int(node.get("id"))
            lat    = float(node.get("lat"))
            lon    = float(node.get("lon"))
            tags   = {t.get("k"): t.get("v") for t in node.findall("tag")}
            name   = tags.get("name")

            is_stop = (
                tags.get("public_transport") == "stop_position"
                or tags.get("highway") == "bus_stop"
                or tags.get("amenity") == "bus_station"
            )

            point = Point(lon, lat)
            geom  = from_shape(point, srid=4326)

            session.merge(OSMNode(osm_id=osm_id, name=name,
                                  is_stop=is_stop, geom=geom))
            node_count += 1

            if is_stop:
                session.merge(BusStop(stop_id=osm_id, name=name, geom=geom))
                stops_dict[osm_id] = point
                stop_count += 1

            nodes_dict[osm_id] = (lon, lat)

            if node_count % 1000 == 0:
                session.commit()
                print(f"  Processed {node_count} nodes...")

        session.commit()
        print(f"✓ Processed {node_count} nodes ({stop_count} bus stops)")

        # Step 2: Ways 
        print("Processing ways...")
        ways_dict = {}
        way_count = 0

        for way in root.findall("way"):
            way_id    = int(way.get("id"))
            node_refs = [int(nd.get("ref")) for nd in way.findall("nd")]
            coords    = [nodes_dict[n] for n in node_refs if n in nodes_dict]

            if len(coords) < 2:
                continue

            tags      = {t.get("k"): t.get("v") for t in way.findall("tag")}
            oneway    = tags.get("oneway", "no")
            is_oneway = oneway in ("yes", "true", "1")
            line      = LineString(coords)
            geom      = from_shape(line, srid=4326)

            session.merge(OSMWay(
                osm_id       = way_id,
                name         = tags.get("name"),
                highway_type = tags.get("highway"),
                is_oneway    = is_oneway,
                foot_access  = tags.get("foot"),
                surface      = tags.get("surface"),
                geom         = geom
            ))
            ways_dict[way_id] = (line, is_oneway)
            way_count += 1

            if way_count % 500 == 0:
                session.commit()
                print(f"  Processed {way_count} ways...")

        session.commit()
        print(f"✓ Processed {way_count} ways")

        # Step 3: Routes
        print("Processing routes...")
        route_count = 0

        for relation in root.findall("relation"):
            tags = {t.get("k"): t.get("v") for t in relation.findall("tag")}

            if tags.get("type") != "route":
                continue

            route_id   = int(relation.get("id"))
            route_name = tags.get("name")
            route_type = tags.get("route")
            direction  = tags.get("direction")

            lines          = []
            way_sequence   = 0
            stop_sequence  = 0
            terminal_stops = []
            added_stops    = set()

            for member in relation.findall("member"):
                mtype = member.get("type")
                role  = member.get("role", "")

                if mtype == "way":
                    way_id = int(member.get("ref"))
                    if way_id in ways_dict:
                        line, _ = ways_dict[way_id]
                        line, _ = ways_dict[way_id]
                        lines.append(line)
                        session.merge(RouteWay(
                            route_id=route_id,
                            way_id=way_id,
                            sequence=way_sequence
                        ))
                        way_sequence += 1

                elif mtype == "node" and role in (
                    "stop", "platform",
                    "stop_entry_only", "stop_exit_only"
                ):
                    node_id = int(member.get("ref"))
                    if node_id in stops_dict and node_id not in added_stops:  # ← check
                        session.merge(RouteStop(
                            route_id=route_id,
                            stop_id=node_id,
                            sequence=stop_sequence
                        ))
                        added_stops.add(node_id) 
                        stop_sequence += 1

                elif mtype == "node" and role in ("start", "end"):
                    node_id = int(member.get("ref"))
                    terminal_stops.append((role, node_id))

            if not lines:
                continue

            multi = MultiLineString(lines)
            geom  = from_shape(multi, srid=4326)

            session.merge(Route(
                route_id=route_id,
                route_name=route_name,
                route_type=route_type,
                direction=direction,
                geom=geom
            ))

            # Handle start/end terminal nodes
            for role, node_id in terminal_stops:
                if node_id not in added_stops: 
                    if node_id in nodes_dict and node_id not in stops_dict:
                        lon, lat  = nodes_dict[node_id]
                        point     = Point(lon, lat)
                        geom_stop = from_shape(point, srid=4326)
                        session.merge(BusStop(
                            stop_id=node_id,
                            name=f"{route_name} ({'Start' if role == 'start' else 'End'})",
                            geom=geom_stop
                        ))
                        stops_dict[node_id] = point

                    if node_id in stops_dict:
                        seq = 0 if role == "start" else 9999
                        session.merge(RouteStop(
                            route_id=route_id,
                            stop_id=node_id,
                            sequence=seq
                        ))
                        added_stops.add(node_id) 
                        stop_sequence += 1

            # Infer intermediate stops from geometry
            if stop_sequence <= 2 and stops_dict:
                print(f"  Inferring stops for '{route_name}'...")
                MAX_DIST = 0.0005

                nearby = []
                for stop_id, stop_point in stops_dict.items():
                    if stop_id not in added_stops:
                        if multi.distance(stop_point) <= MAX_DIST:
                            position = multi.project(stop_point)
                            nearby.append((position, stop_id))

                nearby.sort(key=lambda x: x[0])

                for seq, (_, stop_id) in enumerate(nearby):
                    session.merge(RouteStop(
                        route_id=route_id,
                        stop_id=stop_id,
                        sequence=seq
                    ))
                    added_stops.add(stop_id)

                stop_sequence += len(nearby)

            route_count += 1
            print(f"  ✓ {route_name} ({route_type}) | "
                  f"direction: {direction} | "
                  f"{way_sequence} ways | {stop_sequence} stops")

        session.commit()
        print(f"\n✓ Processed {route_count} routes")
        print("✓ Import complete!")

    except Exception as e:
        print(f"\n✗ Error: {e}")
        session.rollback()
        raise
    finally:
        session.close()


if __name__ == "__main__":
    import os
    xml_file = "lotsOfRoutes.xml"
    if not os.path.exists(xml_file):
        print(f"✗ File '{xml_file}' not found!")
        print(f"  Current directory: {os.getcwd()}")
        sys.exit(1)
    print("Starting OSM import...")
    print("-" * 50)
    import_osm(xml_file)