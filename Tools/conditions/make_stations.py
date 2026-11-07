"""Trims the gathered station lists to the ones the app uses.

python3 Tools/conditions/make_stations.py <gathered conditions-stations.json> FishoDex/Resources/conditions-stations.json

1. NOAA CO-OPS: every Florida station with tide predictions, water temperature or wind.
2. NWS: airport weather stations only (K plus three letters or numbers), which report wind every hour.
3. USGS: one water temperature series per gauge, leaving out groundwater wells (named "G-1234").
"""
import json, re, sys

src, dst = sys.argv[1], sys.argv[2]
d = json.load(open(src))
nws = [s for s in d["nws"] if re.fullmatch(r"K[A-Z0-9]{3}", s["id"])]
seen, usgs = set(), []
for u in d["usgs"]:
    if u["id"] in seen or re.match(r"G\s*-\s*\d", u["name"]):
        continue
    seen.add(u["id"])
    name = re.sub(r",?\s*Fl$", "", u["name"]).strip()
    usgs.append({"id": u["id"], "name": name, "lat": u["lat"], "lon": u["lon"], "series": u["series"]})
coops = [{k: v for k, v in s.items()} for s in d["coops"]]
for s in coops:
    for k in ("tide", "waterTemp", "wind"):
        if not s[k]:
            del s[k]
out = {"checked": d["checked"], "coops": coops, "nws": nws, "usgs": usgs}
with open(dst, "w") as f:
    json.dump(out, f, separators=(",", ":"))
print(f"CO-OPS {len(coops)}, NWS {len(nws)}, USGS {len(usgs)}")
