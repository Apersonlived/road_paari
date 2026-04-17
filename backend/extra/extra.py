"""
OSM Data Importer for RoadPaari
================================
Downloads OSM data from Overpass API and inserts into your existing
osm_node and osm_way tables, then rebuilds the pgRouting topology.

Usage:
    pip install psycopg2-binary requests
    python import_osm.py

    OR to use a pre-downloaded .osm file:
    python import_osm.py --file kathmandu.osm
"""

import argparse
import os
import sys
import xml.etree.ElementTree as ET
from typing import Optional

import psycopg2
import requests

# ── Config ────────────────────────────────────────────────────────────────────
DB_CONFIG = {
    "host":     "localhost",
    "port":     5432,
    "dbname":   "roadpaari",
    "user":     "postgres",
    "password": "postgres",   # ← change this
}

# Kathmandu Valley bounding box  [south, west, north, east]
BBOX = "27.55,85.15,27.85,85.55"

# Highway types to import for pedestrian routing
PEDESTRIAN_HIGHWAY_TYPES = {
    "footway", "path", "steps", "pedestrian", "living_street",
    "residential", "service", "tertiary", "secondary", "primary",
    "unclassified", "trunk_link", "motorway_link", "cycleway",
}

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

OVERPASS_QUERY = f"""
[out:xml][timeout:300][bbox:{BBOX}];
(
  way["highway"~"^(footway|path|steps|pedestrian|living_street|residential|service|tertiary|secondary|primary|unclassified|trunk_link|motorway_link|cycleway)$"];
  >;
);
out body;
"""

# ── Download ──────────────────────────────────────────────────────────────────

def download_osm(output_file: str = "kathmandu.osm") -> str:
    """Download OSM data from Overpass API and save as .osm XML file."""
    print(f"Downloading OSM data for Kathmandu Valley...")
    print(f"Bounding box: {BBOX}")

    response = requests.post(
        OVERPASS_URL,
        data={"data": OVERPASS_QUERY},
        timeout=360,
        stream=True,
    )
    response.raise_for_status()

    total = 0
    with open(output_file, "wb") as f:
        for chunk in response.iter_content(chunk_size=1024 * 1024):
            f.write(chunk)
            total += len(chunk)
            print(f"  Downloaded {total / 1024 / 1024:.1f} MB...", end="\r")

    print(f"\nSaved to {output_file} ({total / 1024 / 1024:.1f} MB)")
    return output_file


# ── Parse ─────────────────────────────────────────────────────────────────────

def parse_osm(filepath: str):
    """
    Parse .osm XML file.
    Returns:
        nodes: dict of osm_id -> {lat, lon, name}
        ways:  list of way dicts with tags and node refs
    """
    print(f"Parsing {filepath}...")
    tree = ET.parse(filepath)
    root = tree.getroot()

    nodes = {}
    for node in root.findall("node"):
        osm_id = int(node.get("id"))
        lat    = float(node.get("lat"))
        lon    = float(node.get("lon"))
        name   = None
        for tag in node.findall("tag"):
            if tag.get("k") == "name":
                name = tag.get("v")
                break
        nodes[osm_id] = {"lat": lat, "lon": lon, "name": name}

    ways = []
    for way in root.findall("way"):
        osm_id   = int(way.get("id"))
        node_refs = [int(nd.get("ref")) for nd in way.findall("nd")]
        tags     = {tag.get("k"): tag.get("v") for tag in way.findall("tag")}

        highway = tags.get("highway")
        if not highway or highway not in PEDESTRIAN_HIGHWAY_TYPES:
            continue
        if tags.get("foot") == "no" or tags.get("access") == "no":
            continue
        if len(node_refs) < 2:
            continue

        ways.append({
            "osm_id":      osm_id,
            "name":        tags.get("name"),
            "highway_type": highway,
            "is_oneway":   tags.get("oneway") == "yes",
            "foot_access": tags.get("foot"),
            "surface":     tags.get("surface"),
            "node_refs":   node_refs,
        })

    print(f"  Found {len(nodes):,} nodes and {len(ways):,} ways")
    return nodes, ways


# ── Build LineString WKT ──────────────────────────────────────────────────────

def build_linestring(node_refs: list, nodes: dict) -> Optional[str]:
    """Build a WKT LineString from ordered node refs."""
    coords = []
    for ref in node_refs:
        n = nodes.get(ref)
        if n:
            coords.append(f"{n['lon']} {n['lat']}")
    if len(coords) < 2:
        return None
    return f"LINESTRING({', '.join(coords)})"


# ── Insert ────────────────────────────────────────────────────────────────────

def insert_data(nodes: dict, ways: list, conn):
    """Insert nodes and ways into the database, skipping duplicates."""
    cur = conn.cursor()

    # ── Nodes ─────────────────────────────────────────────────────────────────
    print("Inserting nodes...")
    node_batch = []
    for osm_id, data in nodes.items():
        node_batch.append((
            osm_id,
            data["name"],
            data["lon"],
            data["lat"],
        ))

    cur.executemany(
        """
        INSERT INTO osm_node (osm_id, name, geom)
        VALUES (%s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 4326))
        ON CONFLICT (osm_id) DO UPDATE SET
            name = EXCLUDED.name,
            geom = EXCLUDED.geom
        """,
        node_batch,
    )
    print(f"  Upserted {len(node_batch):,} nodes")

    # ── Ways ──────────────────────────────────────────────────────────────────
    print("Inserting ways...")
    inserted = 0
    skipped  = 0

    for way in ways:
        wkt = build_linestring(way["node_refs"], nodes)
        if wkt is None:
            skipped += 1
            continue

        cur.execute(
            """
            INSERT INTO osm_way (
                osm_id, name, highway_type,
                is_oneway, foot_access, surface, geom, is_routable
            )
            VALUES (
                %s, %s, %s,
                %s, %s, %s,
                ST_GeomFromText(%s, 4326),
                TRUE
            )
            ON CONFLICT (osm_id) DO UPDATE SET
                name         = EXCLUDED.name,
                highway_type = EXCLUDED.highway_type,
                is_oneway    = EXCLUDED.is_oneway,
                foot_access  = EXCLUDED.foot_access,
                surface      = EXCLUDED.surface,
                geom         = EXCLUDED.geom,
                is_routable  = TRUE
            """,
            (
                way["osm_id"],
                way["name"],
                way["highway_type"],
                way["is_oneway"],
                way["foot_access"],
                way["surface"],
                wkt,
            ),
        )
        inserted += 1

    conn.commit()
    print(f"  Upserted {inserted:,} ways, skipped {skipped} (missing nodes)")


# ── Rebuild pgRouting Topology ────────────────────────────────────────────────

def rebuild_topology(conn):
    """Rebuild pgRouting source/target topology after data load."""
    cur = conn.cursor()
    print("Rebuilding pgRouting topology...")

    # Update lengths
    print("  Computing lengths...")
    cur.execute("""
        UPDATE osm_way
        SET length_meters = ST_Length(geom::geography)
        WHERE length_meters IS NULL OR length_meters = 0
    """)

    # Rebuild vertices table
    print("  Rebuilding vertices table...")
    cur.execute("DROP TABLE IF EXISTS osm_way_vertices_pgr CASCADE")
    cur.execute("""
        CREATE TABLE osm_way_vertices_pgr AS
        SELECT * FROM pgr_extractVertices(
            'SELECT osm_id AS id, geom FROM osm_way WHERE geom IS NOT NULL'
        )
    """)
    cur.execute("ALTER TABLE osm_way_vertices_pgr ADD PRIMARY KEY (id)")
    cur.execute("""
        CREATE INDEX idx_vertices_geom
        ON osm_way_vertices_pgr USING GIST (geom)
    """)

    # Assign source vertices
    print("  Assigning source vertices...")
    cur.execute("""
        UPDATE osm_way e
        SET source = v.id
        FROM osm_way_vertices_pgr v
        WHERE ST_DWithin(ST_StartPoint(e.geom), v.geom, 0.000001)
    """)

    # Assign target vertices
    print("  Assigning target vertices...")
    cur.execute("""
        UPDATE osm_way e
        SET target = v.id
        FROM osm_way_vertices_pgr v
        WHERE ST_DWithin(ST_EndPoint(e.geom), v.geom, 0.000001)
    """)

    # Set costs
    print("  Setting routing costs...")
    cur.execute("""
        UPDATE osm_way
        SET
            cost          = ST_Length(geom::geography),
            reverse_cost  = CASE
                                WHEN is_oneway THEN -1
                                ELSE ST_Length(geom::geography)
                            END,
            length_meters = ST_Length(geom::geography),
            is_routable   = TRUE
        WHERE source IS NOT NULL AND target IS NOT NULL
    """)

    # Mark disconnected ways as non-routable
    cur.execute("""
        UPDATE osm_way
        SET is_routable = FALSE
        WHERE source IS NULL OR target IS NULL
    """)

    conn.commit()

    # Verify
    cur.execute("""
        SELECT
            COUNT(*)                                           AS total,
            COUNT(source)                                      AS has_source,
            COUNT(target)                                      AS has_target,
            COUNT(CASE WHEN is_routable THEN 1 END)           AS routable,
            COUNT(CASE WHEN NOT is_routable THEN 1 END)       AS disconnected
        FROM osm_way
    """)
    row = cur.fetchone()
    print(f"\nTopology summary:")
    print(f"  Total ways:    {row[0]:,}")
    print(f"  Has source:    {row[1]:,}")
    print(f"  Has target:    {row[2]:,}")
    print(f"  Routable:      {row[3]:,}")
    print(f"  Disconnected:  {row[4]:,}")


# ── Test Walking Route ────────────────────────────────────────────────────────

def test_walking_route(conn):
    """Quick sanity check — run a walking route query."""
    cur = conn.cursor()
    print("\nTesting walking route (Lagankhel → Kathmandu center)...")
    cur.execute("""
        SELECT seq, way_name, length_meters
        FROM calculate_walking_route(
            27.6906, 85.3157,
            27.7172, 85.3240,
            5000
        )
        LIMIT 10
    """)
    rows = cur.fetchall()
    if not rows:
        print("  ⚠ No rows returned — check that calculate_walking_route exists")
        return
    for row in rows:
        print(f"  seq={row[0]}  way={row[1]}  len={row[2]:.1f}m")
    if len(rows) == 1 and rows[0][1] == "Direct path":
        print("  ⚠ Still returning direct path — topology may not be connected")
    else:
        print(f"  ✓ Road-following route returned ({len(rows)} segments)")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Import OSM data into RoadPaari DB")
    parser.add_argument(
        "--file", "-f",
        help="Path to existing .osm file (skips download)",
        default=None,
    )
    parser.add_argument(
        "--skip-topology",
        action="store_true",
        help="Skip pgRouting topology rebuild (useful for partial re-runs)",
    )
    parser.add_argument(
        "--test",
        action="store_true",
        help="Run a test walking route query after import",
    )
    args = parser.parse_args()

    # ── Get OSM file ──────────────────────────────────────────────────────────
    osm_file = args.file
    if osm_file is None:
        osm_file = "kathmandu.osm"
        download_osm(osm_file)
    elif not os.path.exists(osm_file):
        print(f"Error: file not found: {osm_file}")
        sys.exit(1)
    else:
        print(f"Using existing file: {osm_file}")

    # ── Parse ─────────────────────────────────────────────────────────────────
    nodes, ways = parse_osm(osm_file)

    # ── Connect ───────────────────────────────────────────────────────────────
    print(f"\nConnecting to database '{DB_CONFIG['dbname']}'...")
    try:
        conn = psycopg2.connect(**DB_CONFIG)
    except psycopg2.OperationalError as e:
        print(f"Connection failed: {e}")
        sys.exit(1)
    print("  Connected")

    # ── Insert ────────────────────────────────────────────────────────────────
    insert_data(nodes, ways, conn)

    # ── Topology ──────────────────────────────────────────────────────────────
    if not args.skip_topology:
        rebuild_topology(conn)
    else:
        print("Skipping topology rebuild")

    # ── Test ──────────────────────────────────────────────────────────────────
    if args.test:
        test_walking_route(conn)

    conn.close()
    print("\nDone!")


if __name__ == "__main__":
    main()