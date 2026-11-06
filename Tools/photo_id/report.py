#!/usr/bin/env python3
"""Write report.md from Create ML's test results, and pick sample photos for the app's screenshots."""
import argparse, json, os, shutil

ap = argparse.ArgumentParser()
ap.add_argument("--data", default="photo-id-data")
ap.add_argument("--model", default="photo-id-model")
ap.add_argument("--split", default="photo-id-split")
ap.add_argument("--out", default="publish")
args = ap.parse_args()

os.makedirs(os.path.join(args.out, "samples"), exist_ok=True)
classes = {c["id"]: c for c in json.load(open("Tools/photo_id/classes.json"))["classes"]}
manifest = json.load(open(os.path.join(args.data, "manifest.json")))
counts = json.load(open(os.path.join(args.data, "counts.json")))
split_info = json.load(open(os.path.join(args.split, "left_out.json"))) if os.path.exists(os.path.join(args.split, "left_out.json")) else {"leftOut": []}
eval_path = os.path.join(args.model, "evaluation.json")
evaluation = json.load(open(eval_path)) if os.path.exists(eval_path) else None
predictions = json.load(open(os.path.join(args.model, "predictions.json"))) if evaluation else []

lines = ["# Photo ID model report", ""]
total = sum(v["train"] + v["test"] for v in counts["counts"].values())
lines += [f"Photos: {total} in {len(counts['counts'])} classes. Skipped while collecting: " +
          ", ".join(f"{k} {v}" for k, v in sorted(counts["skipped"].items())), ""]
if split_info["leftOut"]:
    lines += ["Left out of the model (too few photos): " + ", ".join(split_info["leftOut"]), ""]
best = None
if evaluation:
    lines += [f"Training error {evaluation['trainingError']:.3f}, validation error {evaluation['validationError']:.3f}, "
              f"{evaluation['iterations']} iterations, {evaluation['seconds']:.0f} s.", ""]
    lines += ["| Fit | Test photos | Top 1 | Top 3 |", "|---|---|---|---|"]
    for f in evaluation["fits"]:
        lines.append(f"| {f['fit']} | {f['count']} | {f['top1']:.1%} | {f['top3']:.1%} |")
    best = max(evaluation["fits"], key=lambda f: (f["top3"], f["top1"]))
    lines += ["", f"Best fit: {best['fit']}. How sure the first guess was, and how often it was right:", ""]
    for level, v in sorted(best["sureAt"].items()):
        lines.append(f"- at least {float(level):.0%} sure: {v['share']:.0%} of photos, right {v['right']:.0%} of the time")
    lines += ["", "| Fish | Photos (train/test) | Top 1 | Top 3 |", "|---|---|---|---|"]
    for cid in classes:
        c = counts["counts"].get(cid, {"train": 0, "test": 0})
        r = best["perClass"].get(cid)
        t1 = f"{r['top1']}/{r['count']}" if r else "-"
        t3 = f"{r['top3']}/{r['count']}" if r else "-"
        lines.append(f"| {classes[cid]['name']} ({cid}) | {c['train']}/{c['test']} | {t1} | {t3} |")
    # Most common mix-ups.
    mix = {}
    for p in predictions:
        if p["fit"] == best["fit"] and p["guesses"] and p["guesses"][0]["id"] != p["truth"]:
            k = (p["truth"], p["guesses"][0]["id"])
            mix[k] = mix.get(k, 0) + 1
    lines += ["", "Most common mix-ups (truth -> first guess):", ""]
    for (a, b), n in sorted(mix.items(), key=lambda kv: -kv[1])[:20]:
        lines.append(f"- {a} -> {b}: {n}")
    json.dump({"fit": best["fit"], "top1": best["top1"], "top3": best["top3"]},
              open(os.path.join(args.out, "best_fit.json"), "w"), indent=1)

    # Sample photos for the screenshots: right first guesses, CC0 or CC BY, a few fish.
    by_file = {os.path.basename(p["file"]): p for p in manifest}
    samples = []
    for want in ["snook", "redfish", "mahi", "peacock", "graysnapper", "tarpon", "bass", "sailfish"]:
        for p in predictions:
            m = by_file.get(p["file"])
            if (p["fit"] == best["fit"] and p["truth"] == want and p["guesses"] and p["guesses"][0]["id"] == want
                    and m and (m["license"].startswith("CC BY ") or m["license"] in ("CC0", "Public domain", "CC BY"))):
                shutil.copy(os.path.join(args.data, m["file"]), os.path.join(args.out, "samples", f"{want}.jpg"))
                samples.append({"id": want, "file": f"{want}.jpg", "title": m["title"], "author": m["author"],
                                "license": m["license"], "page": m["page"], "guesses": p["guesses"]})
                break
    json.dump(samples, open(os.path.join(args.out, "samples", "samples.json"), "w"), indent=1, ensure_ascii=False)
open(os.path.join(args.out, "report.md"), "w").write("\n".join(lines) + "\n")
print("\n".join(lines[:40]))
