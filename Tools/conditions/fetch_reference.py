"""Gathers the conditions reference data on a GitHub Actions runner (open internet).

1. stations.json: NOAA CO-OPS stations in Florida that have tide predictions,
   water temperature or wind, so the app can pick the nearest one with no internet.
2. samples/: real responses from each free, keyless source, used by the logic
   tests to check that FishoDex reads them right.

Sources (all U.S. government, public domain, no key):
  NOAA CO-OPS  https://api.tidesandcurrents.noaa.gov  (tides, water temp, wind)
  NWS          https://api.weather.gov                (wind, last 7 days)
  USGS         https://api.waterdata.usgs.gov         (freshwater temperature)
"""
import json, os, sys, time, urllib.request, urllib.error

UA = "FishoDex/1.0 (https://github.com/aadaayy/fishodex)"
OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
os.makedirs(f"{OUT}/samples", exist_ok=True)

def get(url, name=None):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/geo+json, application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            body = r.read()
            headers = dict(r.headers)
            status = r.status
    except urllib.error.HTTPError as e:
        body, headers, status = e.read(), dict(e.headers), e.code
    except Exception as e:
        print(f"FAIL {url}: {e}")
        return None
    print(f"{status} {len(body):>8} {url}")
    if name:
        with open(f"{OUT}/samples/{name}", "wb") as f:
            f.write(body)
        with open(f"{OUT}/samples/{name}.headers.txt", "w") as f:
            f.write(f"status {status}\n" + "\n".join(f"{k}: {v}" for k, v in headers.items()))
    time.sleep(0.5)
    try:
        return json.loads(body)
    except Exception:
        return None

MD = "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json"
DG = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
APP = "&application=FishoDex"

# 1. Stations
stations = {}
for kind in ["tidepredictions", "watertemp", "met"]:
    data = get(f"{MD}?type={kind}" + ("&expand=sensors" if kind == "met" else ""), f"mdapi-{kind}-fl-sample.json" if kind == "met" else None) or {}
    for s in data.get("stations", []):
        if s.get("state") != "FL":
            continue
        sid = str(s["id"])
        e = stations.setdefault(sid, {"id": sid, "name": s.get("name", "").strip(), "lat": round(float(s["lat"]), 4),
                                      "lon": round(float(s["lng"]), 4), "tide": False, "waterTemp": False, "wind": False})
        e[{"tidepredictions": "tide", "watertemp": "waterTemp", "met": "wind"}[kind]] = True
        if kind == "met":
            sensors = [x.get("name", "") for x in (s.get("sensors") or {}).get("sensors", [])] if isinstance(s.get("sensors"), dict) else []
            if sensors:
                e["sensors"] = sensors
        if kind == "tidepredictions":
            e["tideType"] = s.get("type")
rows = sorted(stations.values(), key=lambda s: s["id"])
with open(f"{OUT}/stations.json", "w") as f:
    json.dump({"source": "NOAA CO-OPS metadata API", "fetched": time.strftime("%Y-%m-%d"), "stations": rows}, f, indent=1)
print(f"{len(rows)} Florida stations: tide {sum(s['tide'] for s in rows)}, water temp {sum(s['waterTemp'] for s in rows)}, wind {sum(s['wind'] for s in rows)}")

# NWS weather stations in Florida (for wind; the app asks by station, never by spot)
nws = []
url = "https://api.weather.gov/stations?state=FL&limit=500"
while url:
    page = get(url) or {}
    for f in page.get("features", []):
        p, (lon, lat) = f["properties"], f["geometry"]["coordinates"][:2]
        nws.append({"id": p["stationIdentifier"], "name": p.get("name", ""), "lat": round(lat, 4), "lon": round(lon, 4)})
    nxt = (page.get("pagination") or {}).get("next")
    url = nxt if nxt and page.get("features") else None
    if len(nws) > 3000: break
print(f"{len(nws)} NWS stations in Florida")

# USGS water temperature gauges (instantaneous, still reporting) in South Florida
base = "https://api.waterdata.usgs.gov/ogcapi/v0/collections"
usgs = []
d = get(f"{base}/latest-continuous/items?f=json&parameter_code=00010&bbox=-82.5,24.4,-79.9,27.9&limit=1000", "usgs-latest-temp.json") or {}
cut = time.strftime("%Y-%m-%d", time.gmtime(time.time() - 45 * 86400))
for f in d.get("features", []):
    p = f["properties"]
    if p.get("time", "") < cut or (p.get("qualifier") or []):
        continue
    lon, lat = f["geometry"]["coordinates"][:2]
    usgs.append({"id": p["monitoring_location_id"], "series": p["time_series_id"], "lat": round(lat, 4), "lon": round(lon, 4)})
# names
for u in usgs:
    m = get(f"{base}/monitoring-locations/items/{u['id']}?f=json") or {}
    u["name"] = (m.get("properties") or {}).get("monitoring_location_name", u["id"]).title()
print(f"{len(usgs)} USGS water temperature gauges reporting in South Florida")

with open(f"{OUT}/conditions-stations.json", "w") as f:
    json.dump({"checked": time.strftime("%Y-%m-%d"),
               "coops": [{k: s[k] for k in ("id", "name", "lat", "lon")} | {"tide": s["tide"], "waterTemp": s["waterTemp"],
                          "wind": "Wind" in s.get("sensors", [])} for s in rows if s["tide"] or s["waterTemp"] or "Wind" in s.get("sensors", [])],
               "nws": nws, "usgs": usgs}, f, separators=(",", ":"))

# 2. Samples (Virginia Key, Miami)
st = "8723214"
get(f"{DG}?product=predictions&station={st}&begin_date=20261105&end_date=20261107&datum=MLLW&time_zone=gmt&units=english&interval=hilo&format=json{APP}", "coops-hilo.json")
get(f"{DG}?product=water_temperature&station={st}&begin_date=20261106%2012:00&end_date=20261106%2014:00&time_zone=gmt&units=english&interval=h&format=json{APP}", "coops-water-temp.json")
get(f"{DG}?product=wind&station={st}&begin_date=20261106%2012:00&end_date=20261106%2014:00&time_zone=gmt&units=english&interval=h&format=json{APP}", "coops-wind.json")
get(f"{DG}?product=water_temperature&station=8722746&begin_date=20261106%2012:00&end_date=20261106%2014:00&time_zone=gmt&units=english&interval=h&format=json{APP}", "coops-error.json")
get(f"{DG}?product=predictions&station=9999999&begin_date=20261105&end_date=20261107&datum=MLLW&time_zone=gmt&units=english&interval=hilo&format=json{APP}", "coops-error-station.json")
end = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
start = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - 3 * 3600))
get(f"https://api.weather.gov/stations/KMIA/observations?start={start}&end={end}", "nws-observations.json")
get(f"https://api.weather.gov/stations/KMIA/observations?start=2026-10-01T00:00:00Z&end=2026-10-01T03:00:00Z", "nws-observations-old.json")
if usgs:
    u = usgs[0]
    get(f"{base}/continuous/items?f=json&time_series_id={u['series']}&datetime=2026-11-06T12:00:00Z/2026-11-06T14:00:00Z&limit=50", "usgs-continuous.json")
    get(f"{base}/continuous/items?f=json&time_series_id={u['series']}&datetime=2026-09-01T12:00:00Z/2026-09-01T13:00:00Z&limit=50", "usgs-continuous-old.json")
