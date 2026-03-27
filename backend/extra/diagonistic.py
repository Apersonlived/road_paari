# Run this quick diagnostic script before the full re-import
from lxml import etree
from pathlib import Path

xml_file = "lotsOfRoutes.xml"
tree = etree.parse(xml_file)
root = tree.getroot()

stop_members_found = 0
way_members_found = 0
routes_checked = 0

for relation in root.findall("relation"):
    tags = {t.get("k"): t.get("v") for t in relation.findall("tag")}
    if tags.get("type") != "route":
        continue
    
    routes_checked += 1
    for member in relation.findall("member"):
        role = member.get("role", "")
        mtype = member.get("type")
        if mtype == "way":
            way_members_found += 1
        elif mtype == "node" and role in ("stop", "platform", 
                                          "stop_entry_only", "stop_exit_only"):
            stop_members_found += 1

print(f"Routes found     : {routes_checked}")
print(f"Way members      : {way_members_found}")
print(f"Stop members     : {stop_members_found}")  # ← critical number