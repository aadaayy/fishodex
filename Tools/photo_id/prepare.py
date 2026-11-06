#!/usr/bin/env python3
"""Sort the collected photos into train/<class> and test/<class> folders for Create ML.

A class needs at least --min training photos to go into the model. Classes with
fewer are left out and listed in left_out.json, and the app asks the person to
pick those fish by name.
"""
import argparse, json, os, shutil

ap = argparse.ArgumentParser()
ap.add_argument("--data", default="photo-id-data")
ap.add_argument("--out", default="photo-id-split")
ap.add_argument("--min", type=int, default=8)
args = ap.parse_args()

manifest = json.load(open(os.path.join(args.data, "manifest.json")))
train = {}
for p in manifest:
    if p["split"] == "train":
        train[p["cls"]] = train.get(p["cls"], 0) + 1
included = {c for c, n in train.items() if n >= args.min}
for p in manifest:
    if p["cls"] not in included:
        continue
    dest = os.path.join(args.out, p["split"], p["cls"])
    os.makedirs(dest, exist_ok=True)
    shutil.copy(os.path.join(args.data, p["file"]), os.path.join(dest, os.path.basename(p["file"])))
classes = json.load(open("Tools/photo_id/classes.json"))["classes"]
left_out = [c["id"] for c in classes if c["id"] not in included]
json.dump({"included": sorted(included), "leftOut": left_out}, open(os.path.join(args.out, "left_out.json"), "w"), indent=1)
print(f"{len(included)} classes in the model; left out: {', '.join(left_out) or 'none'}")
