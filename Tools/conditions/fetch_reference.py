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

# 2. Samples (Virginia Key, Miami)
st = "8723214"
get(f"{DG}?product=predictions&station={st}&begin_date=20261105&end_date=20261107&datum=MLLW&time_zone=gmt&units=english&interval=hilo&format=json{APP}", "coops-hilo.json")
# a subordinate station
sub = next((s["id"] for s in rows if s.get("tideType") == "S" and s["lat"] < 26.5), None)
if sub:
    get(f"{DG}?product=predictions&station={sub}&begin_date=20261105&end_date=20261107&datum=MLLW&time_zone=gmt&units=english&interval=hilo&format=json{APP}", "coops-hilo-subordinate.json")
get(f"{DG}?product=water_temperature&station={st}&begin_date=20261106%2012:00&end_date=20261106%2014:00&time_zone=gmt&units=english&interval=h&format=json{APP}", "coops-water-temp.json")
get(f"{DG}?product=wind&station={st}&begin_date=20261106%2012:00&end_date=20261106%2014:00&time_zone=gmt&units=english&interval=h&format=json{APP}", "coops-wind.json")
get(f"{DG}?product=water_temperature&station=8722670&begin_date=20200101&end_date=20200101&time_zone=gmt&units=english&interval=h&format=json{APP}", "coops-error.json")

# NWS
pts = get("https://api.weather.gov/points/25.7617,-80.1918", "nws-points.json") or {}
obs_url = pts.get("properties", {}).get("observationStations")
if obs_url:
    sts = get(obs_url, "nws-stations.json") or {}
    feats = sts.get("features", [])
    if feats:
        sid = feats[0]["properties"]["stationIdentifier"]
        end = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        start = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - 3 * 3600))
        get(f"https://api.weather.gov/stations/{sid}/observations?start={start}&end={end}", "nws-observations.json")

# USGS (freshwater water temperature, parameter 00010) around Lake Okeechobee and Miami-Dade
base = "https://api.waterdata.usgs.gov/ogcapi/v0/collections"
get(f"{base}?f=json", "usgs-collections.json")
get(f"{base}/latest-continuous/items?f=json&parameter_code=00010&bbox=-81.5,25.0,-80.0,27.5&limit=50", "usgs-latest-temp.json")
get(f"{base}/time-series-metadata/items?f=json&parameter_code=00010&bbox=-81.5,25.0,-80.0,27.5&limit=50", "usgs-ts-meta.json")
get(f"{base}/monitoring-locations/items?f=json&bbox=-81.0,26.5,-80.6,27.2&limit=5", "usgs-locations.json")
