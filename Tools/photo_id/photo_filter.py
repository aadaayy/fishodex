"""Weeds out pictures that aren't photos of a real fish (drawings, old book
plates, food, skeletons, faded museum jars, dolphins the mammal, maps) with
OpenAI's CLIP model (MIT license), used only here to sort the training photos.
It never ships in the app.

Scores are kept in <images>/filter_scores.json so photos are scored once.
"""
import json
import os

import torch
from PIL import Image
from transformers import CLIPModel, CLIPProcessor

GOOD = [
    "a photo of a person holding a fish they caught",
    "a photo of a fish caught on a fishing boat",
    "an underwater photo of a live fish",
    "a photo of a fish swimming in an aquarium",
    "a photo of a freshly caught fish lying on a deck or dock",
    "a close-up photo of a fish",
    "a photo of fresh fish on ice at a fish market",
    "a photo of a fish in shallow water",
    "a photo of a fish lying on the grass",
]
BAD = [
    "a drawing or illustration of a fish",
    "a watercolor painting of a fish",
    "an old printed book plate of fish drawings",
    "a cooked fish dish served on a plate",
    "a fish skeleton",
    "a faded preserved fish specimen on a lab table with a ruler and label",
    "a fish preserved in a glass jar of alcohol",
    "a photo of dolphins, the marine mammals",
    "a tiny fish larva under a microscope",
    "a map",
    "a page of text",
    "a photo of a boat with no fish visible",
    "a photo of a bird",
    "a photo of people with no fish",
    "a taxidermy fish mounted on a wall",
    "a raw fish fillet or steak",
    "a photo of a coral reef with no fish",
    "an x-ray of a fish",
]



def as_tensor(out):
    """Newer transformers return an output object here instead of a tensor."""
    if hasattr(out, "norm"):
        return out
    for name in ("text_embeds", "image_embeds", "pooler_output"):
        value = getattr(out, name, None)
        if value is not None:
            return value
    return out[0]

class PhotoFilter:
    def __init__(self, cache_path, threshold=0.45):
        torch.set_num_threads(os.cpu_count() or 4)
        self.model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32").eval()
        self.processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")
        with torch.no_grad():
            text = self.processor(text=GOOD + BAD, return_tensors="pt", padding=True)
            t = as_tensor(self.model.get_text_features(**text))
            self.text = t / t.norm(dim=-1, keepdim=True)
        self.cache_path = cache_path
        self.threshold = threshold
        try:
            self.scores = json.load(open(cache_path))
        except Exception:
            self.scores = {}

    def save(self):
        json.dump(self.scores, open(self.cache_path, "w"))

    def score(self, paths):
        """Fills in a score for each path that has none: the chance it's a real fish photo, and the closest label."""
        todo = [p for p in paths if os.path.basename(p) not in self.scores]
        for i in range(0, len(todo), 32):
            batch = todo[i:i + 32]
            images = []
            for p in batch:
                try:
                    images.append(Image.open(p).convert("RGB"))
                except Exception:
                    images.append(Image.new("RGB", (224, 224)))
            with torch.no_grad():
                pixels = self.processor(images=images, return_tensors="pt")
                f = as_tensor(self.model.get_image_features(**pixels))
                f = f / f.norm(dim=-1, keepdim=True)
                probs = (100.0 * f @ self.text.T).softmax(dim=-1)
            for p, row in zip(batch, probs):
                good = float(row[:len(GOOD)].sum())
                top = int(row.argmax())
                self.scores[os.path.basename(p)] = [round(good, 3), (GOOD + BAD)[top]]

    def keep(self, path):
        s = self.scores.get(os.path.basename(path))
        return s is None or s[0] >= self.threshold

    def label(self, path):
        s = self.scores.get(os.path.basename(path))
        return s[1] if s else ""
