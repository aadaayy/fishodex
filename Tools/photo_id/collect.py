#!/usr/bin/env python3
"""Gather openly licensed fish photos for FishoDex's photo ID.

Runs on a GitHub Actions Linux machine (it needs the open internet).

Sources, and only these:
  1. Wikimedia Commons: each file's own license.
  2. GBIF: photos attached to records from museum and survey datasets, each
     photo's own license. Records from iNaturalist are skipped, because
     iNaturalist's terms of use don't allow its data to train AI models.

Licenses kept: CC0, public domain, CC BY and CC BY-SA (any version). Anything
NonCommercial (NC) or NoDerivatives (ND), or with no clear license, is skipped.

Output (in --out):
  images/<class>/<key>.jpg   photos, at most 500 px on the long side
  manifest.json              every photo kept: class, split, source, license, author
  counts.json                photos per class (train and test)
  sheets/<class>.jpg         a contact sheet per class, to check the photos by eye
  CREDITS.md                 who took each photo and its license

Be polite: one request at a time to each site's API, a few photo downloads at
once, a clear User-Agent, and backing off when a site says to slow down.
"""
import argparse
import concurrent.futures as futures
import hashlib
import html
import io
import json
import os
import random
import re
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

from PIL import Image, ImageDraw, ImageOps

UA = "FishoDexPhotoID/1.0 (https://github.com/aadaayy/fishodex; training photos for an open-source fishing app)"
COMMONS = "https://commons.wikimedia.org/w/api.php"
WIKIDATA = "https://www.wikidata.org/w/api.php"
GBIF = "https://api.gbif.org/v1"
INAT_DATASETS = {"50c9509d-22c7-4a22-a47d-8c48425ef4a7"}

BAD_WORDS = [
    "map", "range", "distribution", "illustration", "drawing", "drawn", "painting", "paint", "engraving",
    "lithograph", "watercolor", "watercolour", "sketch", "plate", "pl", "fmib", "skeleton",
    "skull", "bones", "bone", "x-ray", "xray", "radiograph", "otolith", "scales", "stamp", "logo", "diagram", "chart",
    "poster", "mural", "statue", "sculpture", "coin", "egg", "larva", "fillet", "steak", "sashimi", "sushi",
    "cooked", "grilled", "fried", "dish", "recipe", "menu", "cuisine", "canned", "label", "sign", "icon",
    "taxidermy", "mounted", "fossil", "postcard", "book", "page", "text", "graph", "chromosome", "dna",
    "gill raker", "histolog", "micrograph", "parasite", "dissect", "head of", "jaw", "teeth", "tooth",
]
BAD_CATEGORY_WORDS = [
    "map", "distribution", " art", "illustration", "drawing", "food", "cuisine", "dish", "skeleton",
    "stamp", "logo", "heraldry", "cooked", "sushi", "taxidermy", "fossil", "statue", "sculpture", "video",
    "audio", "sound", "parasite", "anatomy", "skull", "x-ray", "fmib", "plates", "drawn", "painting",
    "postage", "coins", "documents", "text", "book",
]

_lock = threading.Lock()
_last_call = {}
# GBIF asks scripts to use one connection at a time.
_one_at_a_time = {"api.gbif.org": threading.Lock()}


def log(*parts):
    print(*parts, flush=True)


def get(url, params=None, host_gap=0.3, timeout=40, raw=False, tries=6):
    """GET with a per-site gap between calls and backoff on 429/5xx."""
    if params:
        url = url + ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
    host = urllib.parse.urlparse(url).netloc
    for attempt in range(tries):
        with _lock:
            wait = _last_call.get(host, 0) + host_gap - time.time()
            _last_call[host] = max(time.time(), _last_call.get(host, 0) + host_gap)
        if wait > 0:
            time.sleep(wait)
        request = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Encoding": "identity"})
        try:
            single = _one_at_a_time.get(host)
            if single:
                single.acquire()
            try:
                with urllib.request.urlopen(request, timeout=timeout) as response:
                    data = response.read(25_000_000)
            finally:
                if single:
                    single.release()
            return data if raw else json.loads(data)
        except urllib.error.HTTPError as error:
            if error.code in (429, 500, 502, 503, 504):
                pause = float(error.headers.get("Retry-After") or 0) or min(60, 2 ** attempt * 2)
                log(f"  slow down from {host} ({error.code}), waiting {pause:.0f}s")
                time.sleep(pause)
                continue
            if error.code in (403, 404, 410):
                return None
            log(f"  {host} error {error.code}")
            return None
        except Exception as error:  # timeouts, resets
            time.sleep(min(30, 2 ** attempt))
            last = error
    log(f"  gave up on {url[:120]}")
    return None


def strip_html(text):
    text = re.sub(r"<[^>]+>", "", text or "")
    return " ".join(html.unescape(text).split())


def license_ok(code):
    """True for CC0, public domain, CC BY and CC BY-SA. False for NC, ND and anything unclear."""
    c = (code or "").lower().strip()
    if not c:
        return False
    if "nc" in re.split(r"[-_ /]", c) or "noncommercial" in c or "non-commercial" in c:
        return False
    if "nd" in re.split(r"[-_ /]", c) or "noderiv" in c:
        return False
    if c.startswith("cc0") or "publicdomain/zero" in c or "cc-zero" in c or "cc0" in c:
        return True
    if c.startswith("pd") or "public domain" in c or "publicdomain/mark" in c:
        return True
    if re.search(r"cc[- ]by([- ]sa)?([- ]\d(\.\d)?)?", c) or re.search(r"licenses/by(-sa)?/", c):
        return True
    return False


def license_name(code):
    c = (code or "").lower().replace(" ", "-")
    if "zero" in c or "cc0" in c:
        return "CC0"
    if c.startswith("pd") or "public-domain" in c or "publicdomain/mark" in c:
        return "Public domain"
    version = re.search(r"(\d\.\d)", c) or re.search(r"by(?:-sa)?[-/](\d)\b", c)
    name = "CC BY-SA" if "by-sa" in c else "CC BY"
    return f"{name} {version.group(1)}" if version else name


def has_bad_word(text, words):
    t = " " + re.sub(r"[_()\[\],.]", " ", text.lower()) + " "
    return any(re.search(r"(?<![a-z])" + re.escape(w.strip()) + r"(?![a-z])", t) for w in words)


# ---------- Wikimedia Commons ----------

def wikidata_item(taxon):
    """The Wikidata item whose taxon name (P225) is exactly this, and its Commons category."""
    r = get(WIKIDATA, {"action": "wbsearchentities", "search": taxon, "language": "en", "type": "item",
                       "limit": 7, "format": "json"})
    ids = [h["id"] for h in (r or {}).get("search", [])]
    if not ids:
        return None, None
    e = get(WIKIDATA, {"action": "wbgetentities", "ids": "|".join(ids), "props": "claims", "format": "json"})
    for qid in ids:
        claims = (e or {}).get("entities", {}).get(qid, {}).get("claims", {})
        names = [c.get("mainsnak", {}).get("datavalue", {}).get("value") for c in claims.get("P225", [])]
        if taxon in names:
            category = None
            for c in claims.get("P373", []):
                category = c.get("mainsnak", {}).get("datavalue", {}).get("value")
            return qid, category
    return None, None


def commons_category_files(category, depth=2, limit=700):
    files, seen_cats, queue = [], set(), [(category, 0)]
    while queue and len(files) < limit:
        cat, d = queue.pop(0)
        if cat in seen_cats:
            continue
        seen_cats.add(cat)
        params = {"action": "query", "list": "categorymembers", "cmtitle": f"Category:{cat}",
                  "cmtype": "file|subcat", "cmlimit": 500, "format": "json"}
        while True:
            r = get(COMMONS, params)
            if not r:
                break
            for m in r.get("query", {}).get("categorymembers", []):
                title = m["title"]
                if m["ns"] == 14:
                    sub = title.split(":", 1)[1]
                    if d + 1 <= depth and not has_bad_word(sub, BAD_CATEGORY_WORDS):
                        queue.append((sub, d + 1))
                elif m["ns"] == 6:
                    files.append(title)
            if "continue" in r and len(files) < limit:
                params.update(r["continue"])
            else:
                break
    return files


def commons_depicts_files(qid, limit=300):
    out, params = [], {"action": "query", "list": "search", "srsearch": f"haswbstatement:P180={qid} filetype:bitmap",
                       "srnamespace": 6, "srlimit": 100, "format": "json"}
    while len(out) < limit:
        r = get(COMMONS, params)
        if not r:
            break
        out += [h["title"] for h in r.get("query", {}).get("search", [])]
        if "continue" in r:
            params.update(r["continue"])
        else:
            break
    return out


def commons_search_files(query, limit=250):
    """Files whose title matches a search like intitle:"red drum", for photos that
    were never put in the fish's own category (anglers' catch photos often aren't)."""
    out, params = [], {"action": "query", "list": "search", "srsearch": f"{query} filetype:bitmap",
                       "srnamespace": 6, "srlimit": 100, "format": "json"}
    while len(out) < limit:
        r = get(COMMONS, params)
        if not r:
            break
        out += [h["title"] for h in r.get("query", {}).get("search", [])]
        if "continue" in r:
            params.update(r["continue"])
        else:
            break
    return out


def commons_info(titles):
    """License, author and a 500 px thumbnail for each file."""
    out = []
    for i in range(0, len(titles), 50):
        batch = titles[i:i + 50]
        r = get(COMMONS, {"action": "query", "titles": "|".join(batch), "prop": "imageinfo",
                          "iiprop": "url|mime|size|extmetadata", "iiurlwidth": 500, "format": "json",
                          "iiextmetadatafilter": "LicenseShortName|License|LicenseUrl|Artist|Credit|ObjectName"})
        for page in (r or {}).get("query", {}).get("pages", {}).values():
            info = (page.get("imageinfo") or [{}])[0]
            meta = info.get("extmetadata", {})
            def m(k):
                return meta.get(k, {}).get("value", "")
            out.append({
                "title": page.get("title", ""), "mime": info.get("mime", ""),
                "width": info.get("width", 0), "height": info.get("height", 0),
                "thumb": info.get("thumburl") or info.get("url"), "page": info.get("descriptionurl", ""),
                "license": m("License") or m("LicenseShortName"), "licenseShort": m("LicenseShortName"),
                "licenseUrl": m("LicenseUrl"), "author": strip_html(m("Artist")) or strip_html(m("Credit")),
            })
    return out


def from_commons(taxon, search=None):
    """Photos for a taxon (its category and files marked as depicting it), or,
    with search, files whose title matches that search."""
    qid, category = (None, None) if search else wikidata_item(taxon)
    titles = []
    if search:
        titles += commons_search_files(search)
    elif category:
        titles += commons_category_files(category)
    else:
        titles += commons_category_files(taxon)
    if qid:
        titles += commons_depicts_files(qid)
    titles = list(dict.fromkeys(titles))
    titles = [t for t in titles if t.lower().endswith((".jpg", ".jpeg")) and not has_bad_word(t.removeprefix("File:").rsplit(".", 1)[0], BAD_WORDS)]
    photos = []
    for f in commons_info(titles):
        lic = f["license"] or f["licenseShort"]
        if f["mime"] != "image/jpeg" or not license_ok(lic) and not license_ok(f["licenseShort"]):
            continue
        if min(f["width"], f["height"]) < 200:
            continue
        key = "wm-" + hashlib.sha1(f["title"].encode()).hexdigest()[:16]
        photos.append({"key": key, "source": "Wikimedia Commons", "url": f["thumb"], "page": f["page"],
                       "title": f["title"].removeprefix("File:"), "license": license_name(f["licenseShort"] or lic),
                       "licenseUrl": f["licenseUrl"], "author": f["author"][:200] or "Unknown", "taxon": taxon})
    if search:
        log(f"  Commons search {search}: {len(photos)} usable of {len(titles)} files")
    else:
        log(f"  Commons {taxon}: {len(photos)} usable of {len(titles)} files (item {qid}, category {category})")
    return photos


# ---------- GBIF ----------

def from_gbif(taxon, limit=250):
    m = get(f"{GBIF}/species/match", {"name": taxon, "strict": "true"}, host_gap=0.2)
    key = (m or {}).get("usageKey")
    if not key or (m or {}).get("matchType") == "NONE":
        log(f"  GBIF {taxon}: no match")
        return []
    facets = get(f"{GBIF}/occurrence/search", {"taxonKey": key, "mediaType": "StillImage", "limit": 0,
                                                "facet": "datasetKey", "facetLimit": 40}, host_gap=0.2)
    datasets = []
    for f in (facets or {}).get("facets", []):
        for c in f.get("counts", []):
            if c["name"] not in INAT_DATASETS:
                datasets.append((c["name"], c["count"]))
    photos = []
    for dataset, _ in datasets:
        offset = 0
        while len(photos) < limit and offset < 600:
            r = get(f"{GBIF}/occurrence/search", {"taxonKey": key, "datasetKey": dataset, "mediaType": "StillImage",
                                                   "limit": 100, "offset": offset}, host_gap=0.2)
            results = (r or {}).get("results", [])
            for rec in results:
                if rec.get("datasetKey") in INAT_DATASETS:
                    continue
                for media in rec.get("media", []):
                    url = media.get("identifier", "")
                    if media.get("type") != "StillImage" or not url.startswith("http") or "inaturalist" in url.lower():
                        continue
                    lic = media.get("license") or rec.get("license", "")
                    if not license_ok(lic):
                        continue
                    author = media.get("creator") or media.get("rightsHolder") or rec.get("recordedBy") or rec.get("institutionCode") or "Unknown"
                    # GBIF's own resized copy is far quicker than the museum's full-size original.
                    thumb = f"{GBIF}/image/cache/500x/occurrence/{rec.get('key')}/media/{hashlib.md5(url.encode()).hexdigest()}"
                    photos.append({
                        "key": "gb-" + hashlib.sha1(url.encode()).hexdigest()[:16], "source": "GBIF",
                        "url": url, "thumb": thumb, "page": f"https://www.gbif.org/occurrence/{rec.get('key')}",
                        "title": f"{rec.get('datasetName') or rec.get('institutionCode') or 'GBIF record'} {rec.get('key')}",
                        "license": license_name(lic), "licenseUrl": lic if lic.startswith("http") else "",
                        "author": str(author)[:200], "taxon": taxon, "dataset": dataset,
                        "publisher": rec.get("publisher") or rec.get("institutionCode") or "",
                    })
            if r is None or r.get("endOfRecords", True):
                break
            offset += 100
    log(f"  GBIF {taxon}: {len(photos)} usable photos from {len(datasets)} non-iNaturalist datasets")
    return photos


# ---------- Download and check ----------

def dhash(img):
    g = img.convert("L").resize((9, 8), Image.BILINEAR)
    px = list(g.getdata())
    bits = 0
    for row in range(8):
        for col in range(8):
            bits = (bits << 1) | (px[row * 9 + col] > px[row * 9 + col + 1])
    return bits


def colorfulness(img):
    small = img.resize((64, 64))
    total = 0
    for r, g, b in small.getdata():
        total += abs(r - g) + abs(g - b) + abs(r - b)
    return total / (64 * 64 * 3)


def fetch(photo, folder):
    path = os.path.join(folder, photo["key"] + ".jpg")
    if os.path.exists(path):
        try:
            with Image.open(path) as img:
                img = img.convert("RGB")
                return path, dhash(img), "cached"
        except Exception:
            os.remove(path)
    data = None
    if photo.get("thumb"):
        data = get(photo["thumb"], raw=True, host_gap=0.1, timeout=30, tries=2)
    if not data:
        data = get(photo["url"], raw=True, host_gap=0.12, timeout=25, tries=2)
    if not data:
        return None, None, "download failed"
    try:
        img = Image.open(io.BytesIO(data))
        img = ImageOps.exif_transpose(img).convert("RGB")
    except Exception:
        return None, None, "not an image"
    w, h = img.size
    if min(w, h) < 180:
        return None, None, "too small"
    if max(w, h) / min(w, h) > 3.2:
        return None, None, "too narrow"
    if colorfulness(img) < 6:
        return None, None, "black and white"
    img.thumbnail((500, 500), Image.LANCZOS)
    os.makedirs(folder, exist_ok=True)
    img.save(path, "JPEG", quality=88)
    return path, dhash(img), "new"


def contact_sheet(paths, out, title):
    paths = paths[:48]
    cols, size = 8, 120
    rows = max(1, (len(paths) + cols - 1) // cols)
    sheet = Image.new("RGB", (cols * size, rows * size + 28), "white")
    draw = ImageDraw.Draw(sheet)
    draw.text((6, 6), title, fill="black")
    for i, p in enumerate(paths):
        try:
            with Image.open(p) as img:
                img = ImageOps.fit(img.convert("RGB"), (size - 4, size - 4))
                sheet.paste(img, ((i % cols) * size + 2, (i // cols) * size + 30))
        except Exception:
            pass
    sheet.save(out, "JPEG", quality=80)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--classes", default="Tools/photo_id/classes.json")
    ap.add_argument("--out", default="photo-id-data")
    ap.add_argument("--cap", type=int, default=180, help="most photos per class")
    ap.add_argument("--minutes", type=float, default=95, help="stop downloading after this long")
    ap.add_argument("--only", default="", help="comma-separated class ids, for a quick try")
    ap.add_argument("--no-filter", action="store_true", help="skip the real-fish-photo check")
    args = ap.parse_args()

    start = time.time()
    classes = json.load(open(args.classes))["classes"]
    if args.only:
        wanted = set(args.only.split(","))
        classes = [c for c in classes if c["id"] in wanted]
    images = os.path.join(args.out, "images")
    os.makedirs(os.path.join(args.out, "sheets"), exist_ok=True)

    manifest, hashes, reasons = [], {}, {}
    photo_filter = None
    if not args.no_filter:
        from photo_filter import PhotoFilter
        os.makedirs(images, exist_ok=True)
        photo_filter = PhotoFilter(os.path.join(images, "filter_scores_v2.json"))
    for c in classes:
        log(f"{c['id']} ({c['name']})")
        candidates = []
        per_taxon_cap = c.get("perTaxonCap")
        for taxon in c["taxa"]:
            found = from_commons(taxon) + from_gbif(taxon)
            random.Random(taxon).shuffle(found)
            if per_taxon_cap:
                found = found[:per_taxon_cap * 2]
            candidates += [dict(p, perTaxonCap=per_taxon_cap) for p in found]
        for query in c.get("search", []):
            # Only pages that also talk about fish or fishing, so people and places named Snook or Mahi stay out.
            candidates += [dict(p, perTaxonCap=None, search=query)
                           for p in from_commons(c["taxa"][0], search=f"{query} (fish OR fishing OR caught OR angler)")]
        candidates = list({p["key"]: p for p in candidates}.values())
        # Commons first (thumbnails are light), then GBIF, in a steady order.
        candidates.sort(key=lambda p: (p["source"] != "Wikimedia Commons", hashlib.sha1(p["key"].encode()).hexdigest()))
        kept, per_taxon = [], {}
        folder = os.path.join(images, c["id"])
        # Share the time left fairly among the fish still to do, so one slow site can't starve the rest.
        left = len(classes) - classes.index(c)
        class_deadline = time.time() + max(240, (args.minutes * 60 - (time.time() - start)) / left * 1.5)
        with futures.ThreadPoolExecutor(max_workers=4) as pool:
            for i in range(0, len(candidates), 16):
                if len(kept) >= args.cap or time.time() - start > args.minutes * 60 or time.time() > class_deadline:
                    break
                batch = []
                for p in candidates[i:i + 16]:
                    if per_taxon_cap and per_taxon.get(p["taxon"], 0) >= per_taxon_cap:
                        continue
                    if photo_filter and not photo_filter.keep(p["key"] + ".jpg", strict=bool(p.get("search"))):
                        reasons["not a fish photo (seen before)"] = reasons.get("not a fish photo (seen before)", 0) + 1
                        continue
                    batch.append((p, pool.submit(fetch, p, folder)))
                fetched = []
                for p, job in batch:
                    path, h, why = job.result()
                    reasons[why] = reasons.get(why, 0) + 1
                    if path:
                        fetched.append((p, path, h))
                if photo_filter:
                    photo_filter.score([path for _, path, _ in fetched])
                for p, path, h in fetched:
                    if photo_filter and not photo_filter.keep(path, strict=bool(p.get("search"))):
                        os.remove(path)
                        why = "not a fish photo: " + photo_filter.label(path)
                        reasons[why] = reasons.get(why, 0) + 1
                        continue
                    dupe = any(bin(oh ^ h).count("1") <= 4 for oh in hashes.values())
                    too_many = len(kept) >= args.cap or (per_taxon_cap and per_taxon.get(p["taxon"], 0) >= per_taxon_cap)
                    if dupe or too_many:
                        os.remove(path)
                        why = "duplicate" if dupe else "over the cap"
                        reasons[why] = reasons.get(why, 0) + 1
                        continue
                    hashes[path] = h
                    per_taxon[p["taxon"]] = per_taxon.get(p["taxon"], 0) + 1
                    kept.append(dict(p, file=os.path.relpath(path, args.out), cls=c["id"]))
        if photo_filter:
            photo_filter.save()
        # Hold back about 15% for testing, chosen by a hash so it never changes.
        kept.sort(key=lambda p: hashlib.sha1(p["key"].encode()).hexdigest())
        n_test = max(2, round(len(kept) * 0.15)) if len(kept) >= 10 else (1 if len(kept) >= 4 else 0)
        for i, p in enumerate(kept):
            p["split"] = "test" if i < n_test else "train"
            p.pop("perTaxonCap", None)
        manifest += kept
        contact_sheet([os.path.join(args.out, p["file"]) for p in kept], os.path.join(args.out, "sheets", f"{c['id']}.jpg"),
                      f"{c['name']} ({c['id']}): {len(kept)} photos")
        log(f"  kept {len(kept)} for {c['id']} ({time.time() - start:.0f}s so far)")

    counts = {}
    for p in manifest:
        counts.setdefault(p["cls"], {"train": 0, "test": 0})[p["split"]] += 1
    json.dump(manifest, open(os.path.join(args.out, "manifest.json"), "w"), indent=1, ensure_ascii=False)
    json.dump({"counts": counts, "skipped": reasons}, open(os.path.join(args.out, "counts.json"), "w"), indent=1)

    with open(os.path.join(args.out, "CREDITS.md"), "w") as f:
        f.write("# Photo ID training photos\n\n")
        f.write("FishoDex's photo ID was trained on these openly licensed photos. Each is used under its own license "
                "(CC0, public domain, CC BY or CC BY-SA). The photos are not shipped in the app.\n\n")
        for c in classes:
            rows = [p for p in manifest if p["cls"] == c["id"]]
            if not rows:
                continue
            f.write(f"## {c['name']}\n\n")
            for p in rows:
                f.write(f"- [{p['title']}]({p['page']}) by {p['author']}, {p['license']} ({p['source']})\n")
            f.write("\n")
    log(json.dumps({"total": len(manifest), "skipped": reasons}))
    log("photos per class: " + ", ".join(f"{k} {v['train'] + v['test']}" for k, v in counts.items()))


if __name__ == "__main__":
    main()
