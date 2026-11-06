"""Builds FishoDex/Resources/Assets.xcassets from the approved card art.

Run from the repo root:  python3 Tools/make_assets.py /path/to/fishodex/art
Each card and silhouette becomes an image set named card-<id> / sil-<id>,
shrunk to 600 x 780 (big enough for the open Duo's card pane).
"""
import json, os, sys, glob, io, math
import xml.etree.ElementTree as ET
import cairosvg
from PIL import Image, ImageDraw

ART = sys.argv[1] if len(sys.argv) > 1 else '/mnt/project-files/fishodex/art'
OUT = 'FishoDex/Resources/Assets.xcassets'
SIZE = (600, 780)

def write_json(path, obj):
    with open(path, 'w') as f:
        json.dump(obj, f, indent=2)

os.makedirs(OUT, exist_ok=True)
write_json(f'{OUT}/Contents.json', {'info': {'author': 'xcode', 'version': 1}})

count = 0
for water in ('freshwater', 'inshore', 'offshore'):
    for path in sorted(glob.glob(f'{ART}/{water}/*-caught.png')):
        base = os.path.basename(path)[:-len('-caught.png')]   # 001-bass
        key = base.split('-', 1)[1]
        for kind, suffix in (('card', 'caught'), ('sil', 'silhouette')):
            src = f'{ART}/{water}/{base}-{suffix}.png'
            name = f'{kind}-{key}'
            d = f'{OUT}/{name}.imageset'
            os.makedirs(d, exist_ok=True)
            im = Image.open(src).convert('RGBA').resize(SIZE, Image.LANCZOS)
            im.save(f'{d}/{name}.png', optimize=True)
            write_json(f'{d}/Contents.json', {
                'images': [{'filename': f'{name}.png', 'idiom': 'universal'}],
                'info': {'author': 'xcode', 'version': 1}})
            count += 1

# Fish on their own (no card), for list rows and the unlock moment: the
# fish group is the one translate(...) scale(...) group in each card's SVG.
NS = '{http://www.w3.org/2000/svg}'
ET.register_namespace('', 'http://www.w3.org/2000/svg')

def fish_only(svg_path, width=520):
    root = ET.parse(svg_path).getroot()
    def find(el):
        for c in el:
            tr = c.get('transform') or ''
            if c.tag == NS + 'g' and tr.startswith('translate(') and 'scale' in tr:
                return c
            r = find(c)
            if r is not None:
                return r
    fish = find(root)
    new = ET.Element(NS + 'svg', {'width': '600', 'height': '780', 'viewBox': '0 0 600 780'})
    for d in root:
        if d.tag == NS + 'defs':
            new.append(d)
    new.append(fish)
    im = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=ET.tostring(new), output_width=1200, output_height=1560)))
    im = im.crop(im.getbbox())
    return im.resize((width, round(im.size[1] * width / im.size[0])), Image.LANCZOS)

for water in ('freshwater', 'inshore', 'offshore'):
    for path in sorted(glob.glob(f'{ART}/{water}/*-caught.svg')):
        key = os.path.basename(path)[:-len('-caught.svg')].split('-', 1)[1]
        name = f'fish-{key}'
        d = f'{OUT}/{name}.imageset'
        os.makedirs(d, exist_ok=True)
        fish_only(path).save(f'{d}/{name}.png', optimize=True)
        write_json(f'{d}/Contents.json', {
            'images': [{'filename': f'{name}.png', 'idiom': 'universal'}],
            'info': {'author': 'xcode', 'version': 1}})

# App icon: the Florida bass on a sunny burst over flats water.
icon = Image.new('RGB', (1024, 1024), '#2FA9BC')
dr = ImageDraw.Draw(icon)
cx, cy = 512, 540
for i in range(16):
    a0 = i * 2 * math.pi / 16; a1 = a0 + math.pi / 16
    dr.polygon([(cx, cy), (cx + 1100 * math.cos(a0), cy + 1100 * math.sin(a0)),
                (cx + 1100 * math.cos(a1), cy + 1100 * math.sin(a1))], fill='#5CC3D0')
dr.ellipse((cx - 380, cy - 380, cx + 380, cy + 380), fill='#FFC72C', outline='#16213E', width=22)
fish = fish_only(f'{ART}/freshwater/001-bass-caught.svg', width=900)
icon.paste(fish, ((1024 - fish.size[0]) // 2, cy - fish.size[1] // 2 - 10), fish)
d = f'{OUT}/AppIcon.appiconset'
os.makedirs(d, exist_ok=True)
icon.save(f'{d}/AppIcon.png')
write_json(f'{d}/Contents.json', {
    'images': [{'filename': 'AppIcon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
    'info': {'author': 'xcode', 'version': 1}})
d = f'{OUT}/AccentColor.colorset'
os.makedirs(d, exist_ok=True)
write_json(f'{d}/Contents.json', {
    'colors': [{'idiom': 'universal', 'color': {'color-space': 'srgb', 'components': {
        'red': '0xFF', 'green': '0x6B', 'blue': '0x2C', 'alpha': '1.000'}}}],
    'info': {'author': 'xcode', 'version': 1}})
print(count, 'images')
