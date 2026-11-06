#!/usr/bin/env python3
"""A second way to build photo ID, to compare with Create ML: Meta's DINOv2
small image model (Apache 2.0 license) with a FishoDex layer trained on top,
converted to Core ML.

Runs on a GitHub Actions Linux machine:
  1. Turns every training and test photo into DINOv2 features (plus a mirrored
     copy of each training photo).
  2. Trains a logistic regression layer on the training features, picking its
     strength on a slice of the training photos.
  3. Tests it on the held-back photos (top 1 and top 3), the same photos
     Create ML is tested on.
  4. Builds the whole thing (photo in, fish names out) as FishIDProbe.mlpackage,
     with 8-bit weights to keep the app small.
"""
import argparse
import json
import os
import time

import numpy as np
import torch
from PIL import Image, ImageOps
from sklearn.linear_model import LogisticRegression

SIZE = 224
MEAN = [0.485, 0.456, 0.406]
STD = [0.229, 0.224, 0.225]


def log(*a):
    print(*a, flush=True)


def load_backbone(name):
    from transformers import AutoModel
    model = AutoModel.from_pretrained(name, attn_implementation="eager").eval()
    return model


class Features(torch.nn.Module):
    """Photo (0-255 RGB, SIZE x SIZE) -> DINOv2 CLS token joined with the mean patch token."""

    def __init__(self, backbone):
        super().__init__()
        self.backbone = backbone
        self.register_buffer("mean", torch.tensor(MEAN).view(1, 3, 1, 1) * 255)
        self.register_buffer("std", torch.tensor(STD).view(1, 3, 1, 1) * 255)
        # Fix the position table at SIZE so the converted model has no resizing step.
        emb = backbone.embeddings
        with torch.no_grad():
            dummy = torch.zeros(1, 3, SIZE, SIZE)
            tokens = emb.patch_embeddings(dummy)
            cls = emb.cls_token.expand(1, -1, -1)
            fixed = emb.interpolate_pos_encoding(torch.cat([cls, tokens], dim=1), SIZE, SIZE)
        self.register_buffer("pos", fixed.detach().clone())

    def forward(self, image):
        x = (image - self.mean) / self.std
        emb = self.backbone.embeddings
        tokens = emb.patch_embeddings(x)
        cls = emb.cls_token.expand(x.shape[0], -1, -1)
        h = torch.cat([cls, tokens], dim=1) + self.pos
        for layer in self.backbone.encoder.layer:
            out = layer(h)
            h = out[0] if isinstance(out, (tuple, list)) else out
        h = self.backbone.layernorm(h)
        return torch.cat([h[:, 0], h[:, 1:].mean(dim=1)], dim=1)


class Classifier(torch.nn.Module):
    def __init__(self, features, weight, bias):
        super().__init__()
        self.features = features
        self.linear = torch.nn.Linear(weight.shape[1], weight.shape[0])
        with torch.no_grad():
            self.linear.weight.copy_(torch.tensor(weight, dtype=torch.float32))
            self.linear.bias.copy_(torch.tensor(bias, dtype=torch.float32))

    def forward(self, image):
        return torch.softmax(self.linear(self.features(image)), dim=1)


def fit_photo(path, mode):
    img = ImageOps.exif_transpose(Image.open(path)).convert("RGB")
    if mode == "centerCrop":
        img = ImageOps.fit(img, (SIZE, SIZE), Image.BICUBIC)
    else:  # scaleFit: whole photo, padded
        img = ImageOps.pad(img, (SIZE, SIZE), Image.BICUBIC, color=(0, 0, 0))
    return img


def to_tensor(imgs):
    arr = np.stack([np.asarray(i, dtype=np.float32) for i in imgs]).transpose(0, 3, 1, 2)
    return torch.from_numpy(arr)


def embed(model, paths, mode, flip=False, batch=32):
    out = []
    with torch.no_grad():
        for i in range(0, len(paths), batch):
            imgs = [fit_photo(p, mode) for p in paths[i:i + batch]]
            if flip:
                imgs = [ImageOps.mirror(im) for im in imgs]
            out.append(model(to_tensor(imgs)).numpy())
    return np.concatenate(out) if out else np.zeros((0, 768))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--split", default="photo-id-split")
    ap.add_argument("--out", default="photo-id-probe")
    ap.add_argument("--backbone", default="facebook/dinov2-small")
    ap.add_argument("--mode", default="centerCrop")
    ap.add_argument("--bits", type=int, default=8)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    torch.set_num_threads(os.cpu_count() or 4)
    start = time.time()

    def listing(part):
        rows = []
        root = os.path.join(args.split, part)
        for cls in sorted(os.listdir(root)):
            d = os.path.join(root, cls)
            if os.path.isdir(d):
                rows += [(os.path.join(d, f), cls) for f in sorted(os.listdir(d)) if f.endswith(".jpg")]
        return rows

    train, test = listing("train"), listing("test")
    labels = sorted({c for _, c in train})
    index = {c: i for i, c in enumerate(labels)}
    log(f"{len(train)} training photos, {len(test)} test photos, {len(labels)} classes")

    features = Features(load_backbone(args.backbone)).eval()
    xtr = embed(features, [p for p, _ in train], args.mode)
    xtr_flip = embed(features, [p for p, _ in train], args.mode, flip=True)
    ytr = np.array([index[c] for _, c in train])
    xte = embed(features, [p for p, _ in test], args.mode)
    yte = np.array([index.get(c, -1) for _, c in test])
    log(f"features done in {time.time() - start:.0f}s")

    # Pick the regularization on a held-out tenth of the training photos.
    rng = np.random.RandomState(0)
    held = rng.rand(len(ytr)) < 0.1
    best_c, best_acc = 1.0, -1
    for c in [0.1, 0.3, 1.0, 3.0, 10.0]:
        clf = LogisticRegression(C=c, max_iter=3000, class_weight="balanced")
        clf.fit(np.concatenate([xtr[~held], xtr_flip[~held]]), np.concatenate([ytr[~held], ytr[~held]]))
        acc = (clf.predict(xtr[held]) == ytr[held]).mean()
        log(f"  C={c}: held-out accuracy {acc:.3f}")
        if acc > best_acc:
            best_c, best_acc = c, acc
    clf = LogisticRegression(C=best_c, max_iter=5000, class_weight="balanced")
    clf.fit(np.concatenate([xtr, xtr_flip]), np.concatenate([ytr, ytr]))

    probs = clf.predict_proba(xte)
    order = np.argsort(-probs, axis=1)
    top1 = float(np.mean(order[:, 0] == yte))
    top3 = float(np.mean([y in o[:3] for y, o in zip(yte, order)]))
    per_class = {}
    for (path, truth), o in zip(test, order):
        r = per_class.setdefault(truth, {"count": 0, "top1": 0, "top3": 0})
        r["count"] += 1
        r["top1"] += int(labels[o[0]] == truth)
        r["top3"] += int(truth in [labels[k] for k in o[:3]])
    sure = {}
    for level in [0.3, 0.5, 0.7, 0.85]:
        m = probs.max(axis=1) >= level
        sure[f"{level:.2f}"] = {"share": float(m.mean()), "right": float((order[m, 0] == yte[m]).mean()) if m.any() else 0.0}
    predictions = [{"file": os.path.basename(p), "truth": t, "fit": args.mode,
                    "guesses": [{"id": labels[k], "confidence": float(probs[i, k])} for k in order[i, :5]]}
                   for i, (p, t) in enumerate(test)]
    log(f"DINOv2 probe: top-1 {top1:.1%}, top-3 {top3:.1%} (C={best_c})")
    json.dump({"backbone": args.backbone, "fit": args.mode, "C": best_c, "count": len(test), "top1": top1, "top3": top3,
               "sureAt": sure, "perClass": per_class, "seconds": time.time() - start},
              open(os.path.join(args.out, "probe_evaluation.json"), "w"), indent=1)
    json.dump(predictions, open(os.path.join(args.out, "probe_predictions.json"), "w"))

    # Build the Core ML model: photo in, fish names and how sure out.
    import coremltools as ct
    full = Classifier(features, clf.coef_, clf.intercept_).eval()
    example = torch.rand(1, 3, SIZE, SIZE) * 255
    with torch.no_grad():
        traced = torch.jit.trace(full, example)
        check = full(example)
    mlmodel = ct.convert(
        traced,
        inputs=[ct.ImageType(name="image", shape=(1, 3, SIZE, SIZE), color_layout=ct.colorlayout.RGB)],
        classifier_config=ct.ClassifierConfig(labels),
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.iOS17,
        convert_to="mlprogram",
    )
    if args.bits and args.bits < 16:
        from coremltools.optimize.coreml import OpPalettizerConfig, OptimizationConfig, palettize_weights
        config = OptimizationConfig(global_config=OpPalettizerConfig(mode="kmeans", nbits=args.bits, weight_threshold=2048))
        mlmodel = palettize_weights(mlmodel, config)
    mlmodel.short_description = ("Names South Florida fish from a photo, for FishoDex. Label 'other' means a fish "
                                 "that isn't in the dex. Built on DINOv2 small (Apache 2.0).")
    mlmodel.license = "DINOv2 weights: Apache 2.0 (Meta). Fish layer trained on openly licensed photos; see Tools/photo_id/CREDITS.md."
    mlmodel.author = "FishoDex"
    path = os.path.join(args.out, "FishIDProbe.mlpackage")
    mlmodel.save(path)
    size = sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(path) for f in fs)
    log(f"saved {path} ({size / 1e6:.1f} MB), check output {tuple(check.shape)}, total {time.time() - start:.0f}s")


if __name__ == "__main__":
    main()
