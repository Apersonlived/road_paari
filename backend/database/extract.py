# Import external packages
from lxml import etree
from shapely.geometry import Point, LineString, MultiLineString
from geoalchemy2.shape import from_shape
import sys
from pathlib import Path

# Add the project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

# Now import from backend package
from backend.app.core.database import SessionLocal
from backend.model.transport import OSMNode, OSMWay, Route, RouteWay, BusStop

def import_osm(xml_file):
    """Import OSM data from XML file into PostgreSQL database"""
    session = SessionLocal()
    
    try:
        print(f"Parsing XML file: {xml_file}")
        tree = etree.parse(xml_file)
        root = tree.getroot()

        nodes_dict = {}
        
        print("Processing nodes...")
        # ---------- Process nodes ----------
        node_count = 0
        stop_count = 0
        
        for node in root.findall("node"):
            osm_id = int(node.get("id"))
            lat = float(node.get("lat"))
            lon = float(node.get("lon"))

            tags = {t.get("k"): t.get("v") for t in node.findall("tag")}
            name = tags.get("name")
            is_stop = tags.get("public_transport") == "stop_position"

            point = Point(lon, lat)
            geom = from_shape(point, srid=4326)

            db_node = OSMNode(
                osm_id=osm_id,
                name=name,
                is_stop=is_stop,
                geom=geom
            )
            session.merge(db_node)
            node_count += 1

            if is_stop:
                session.merge(BusStop(
                    stop_id=osm_id,
                    name=name,
                    geom=geom
                ))
                stop_count += 1

            nodes_dict[osm_id] = (lon, lat)
            
            # Commit in batches to avoid memory issues
            if node_count % 1000 == 0:
                session.commit()
                print(f"  Processed {node_count} nodes...")

        session.commit()
        print(f"✓ Processed {node_count} nodes ({stop_count} bus stops)")

        # ---------- Process ways ----------
        print("Processing ways...")
        ways_dict = {}
        way_count = 0

        for way in root.findall("way"):
            way_id = int(way.get("id"))

            node_refs = [int(nd.get("ref")) for nd in way.findall("nd")]
            coords = [nodes_dict[n] for n in node_refs if n in nodes_dict]

            if len(coords) < 2:
                continue

            tags = {t.get("k"): t.get("v") for t in way.findall("tag")}

            line = LineString(coords)
            geom = from_shape(line, srid=4326)

            db_way = OSMWay(
                osm_id=way_id,
                name=tags.get("name"),
                highway_type=tags.get("highway"),
                geom=geom
            )

            session.merge(db_way)
            ways_dict[way_id] = line
            way_count += 1
            
            # Commit in batches
            if way_count % 500 == 0:
                session.commit()
                print(f"  Processed {way_count} ways...")

        session.commit()
        print(f"✓ Processed {way_count} ways")

        # ---------- Process routes ----------
        print("Processing routes...")
        route_count = 0

        for relation in root.findall("relation"):
            tags = {t.get("k"): t.get("v") for t in relation.findall("tag")}

            if tags.get("type") != "route":
                continue

            route_id = int(relation.get("id"))
            route_name = tags.get("name")
            route_type = tags.get("route")

            lines = []
            sequence = 0

            for member in relation.findall("member"):
                if member.get("type") == "way":
                    way_id = int(member.get("ref"))

                    if way_id in ways_dict:
                        lines.append(ways_dict[way_id])
                        session.merge(RouteWay(
                            route_id=route_id,
                            way_id=way_id,
                            sequence=sequence
                        ))
                        sequence += 1

            if lines:
                multi = MultiLineString(lines)
                geom = from_shape(multi, srid=4326)

                session.merge(Route(
                    route_id=route_id,
                    route_name=route_name,
                    route_type=route_type,
                    geom=geom
                ))
                route_count += 1
                print(f"  Added route: {route_name} ({route_type})")

        session.commit()
        print(f"✓ Processed {route_count} routes")
        
        print("\n Successful Import!")
        
    except Exception as e:
        print(f"\n Error during import: {e}")
        session.rollback()
        raise
        
    finally:
        session.close()


if __name__ == "__main__":
    import os
    
    # Get the XML file path
    xml_file = "lotsOfRoutes.xml"
    
    # Check if file exists
    if not os.path.exists(xml_file):
        print(f"Error: File '{xml_file}' not found!")
        print(f"Current directory: {os.getcwd()}")
        print("\nUsage: python -m backend.database.extract")
        print("Make sure 'lotsOfRoutes.xml' is in the project root directory")
        sys.exit(1)
    
    print("Starting OSM data import...")
    print(f"XML file: {xml_file}")
    print("-" * 50)
    
    import_osm(xml_file)