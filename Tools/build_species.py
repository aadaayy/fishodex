"""Builds FishoDex/Resources/species.json from the researched data files.

Run from the repo root:  python3 Tools/build_species.py /path/to/fishodex/data
Inputs: species-base.json (names, rarity, habitat), facts-a.json and
facts-b.json (fun facts and blurbs, each checked against a source), and
limits.json (Florida rules from FWC, with the date they were checked).
"""
import json, sys

DATA = sys.argv[1] if len(sys.argv) > 1 else '/mnt/project-files/fishodex/data'
base = json.load(open(f'{DATA}/species-base.json'))
facts = {**json.load(open(f'{DATA}/facts-a.json')), **json.load(open(f'{DATA}/facts-b.json'))}
limits = json.load(open(f'{DATA}/limits.json'))

# Local nicknames people will type when they search.
ALIASES = {
    'bass': ['largemouth bass', 'black bass', 'bigmouth'],
    'peacock': ['peacock bass', 'peacock'],
    'sunshine': ['hybrid striped bass', 'hybrid bass'],
    'bluegill': ['bream', 'brim', 'sunfish'],
    'redear': ['shellcracker', 'bream', 'sunfish'],
    'spottedsun': ['stumpknocker', 'bream', 'sunfish'],
    'warmouth': ['goggle eye', 'bream'],
    'crappie': ['speckled perch', 'specks', 'specs'],
    'pickerel': ['jackfish', 'pike'],
    'mayan': ['atomic sunfish', 'cichlid'],
    'oscar': ['cichlid'],
    'jaguar': ['jaguar cichlid', 'guapote', 'cichlid'],
    'midas': ['red devil', 'cichlid'],
    'acara': ['cichlid'],
    'bluetilapia': ['tilapia'],
    'spottedtilapia': ['tilapia'],
    'snakehead': ['bullseye snakehead', 'goldline snakehead', 'snakehead fish'],
    'knifefish': ['knife fish', 'featherback'],
    'gar': ['garfish', 'gar fish'],
    'bowfin': ['mudfish', 'grinnel', 'dogfish'],
    'channelcat': ['catfish', 'channel cat'],
    'whitecat': ['catfish'],
    'walkingcat': ['catfish'],
    'snook': ['linesider', 'robalo'],
    'tarpon': ['silver king', 'sabalo'],
    'redfish': ['red drum', 'red', 'puppy drum'],
    'seatrout': ['speckled trout', 'trout', 'speck', 'yellowmouth'],
    'bonefish': ['gray ghost'],
    'permit': [],
    'graysnapper': ['mangrove snapper', 'mango', 'snapper'],
    'lanesnapper': ['candy snapper', 'snapper'],
    'muttonsnapper': ['mutton', 'snapper'],
    'sheepshead': ['convict fish'],
    'blackdrum': ['drum'],
    'crevalle': ['jack', 'jack crevalle'],
    'ladyfish': ['skipjack', 'poor mans tarpon'],
    'pompano': [],
    'spanishmack': ['spanish', 'mackerel'],
    'barracuda': ['cuda', 'barracuda'],
    'bluefish': ['snapper blue', 'chopper'],
    'gafftop': ['gafftopsail', 'sail cat', 'catfish'],
    'lookdown': ['moonfish'],
    'goliath': ['jewfish', 'grouper'],
    'mahi': ['dolphin', 'dorado', 'mahi mahi'],
    'sailfish': ['sail', 'billfish'],
    'kingmack': ['kingfish', 'king', 'smoker'],
    'wahoo': ['ono'],
    'blackfin': ['tuna'],
    'yellowfin': ['tuna', 'ahi'],
    'littletunny': ['bonito', 'false albacore', 'tuna'],
    'cobia': ['ling', 'lemonfish'],
    'amberjack': ['aj', 'reef donkey', 'amberjack'],
    'almaco': ['jack'],
    'africanpompano': ['threadfish', 'pompano'],
    'yellowtail': ['flag', 'snapper'],
    'vermilion': ['beeliner', 'b liner', 'snapper'],
    'redgrouper': ['grouper'],
    'blackgrouper': ['grouper'],
    'hogfish': ['hog snapper'],
    'trigger': ['triggerfish'],
    'lionfish': ['red lionfish'],
    'bluemarlin': ['marlin', 'billfish'],
    'swordfish': ['sword', 'broadbill'],
}

NON_NATIVE = {'peacock', 'mayan', 'oscar', 'jaguar', 'midas', 'acara', 'bluetilapia',
              'spottedtilapia', 'snakehead', 'knifefish', 'walkingcat', 'lionfish'}

# Fact edits after review (kept here so a rebuild keeps them).
OVERRIDES = {
    # The jellyfish idea is only a guess, so the card sticks to what FWC confirms.
    'africanpompano': {'funFact': 'Young African pompano trail long threadlike streamers from their fins. '
                                  'Adults lose them as they grow, so a big one looks like a different fish.'},
}

out = []
for b in base:
    f = facts[b['id']]
    l = dict(limits['species'][b['id']])
    l.pop('unverified', None)
    extra = l.pop('extraUrl', None)
    entry = {
        'id': b['id'], 'number': b['number'], 'name': b['name'], 'scientific': b['scientific'],
        'rarity': b['rarity'], 'habitat': b['habitat'], 'where': b['where'],
        'about': f['about'], 'funFact': f['funFact'], 'maxSize': f.get('maxSize'),
        'nonNative': b['id'] in NON_NATIVE, 'aliases': ALIASES.get(b['id'], []),
        'limits': {k: v for k, v in l.items() if v is not None},
        'sources': f.get('sources', []) + ([extra] if extra else []),
    }
    entry.update(OVERRIDES.get(b['id'], {}))
    out.append(entry)

assert len(out) == 63 and len({e['id'] for e in out}) == 63
for e in out:
    for key in ('funFact', 'about'):
        assert '—' not in e[key], (e['id'], key)
json.dump({'limitsCheckedOn': limits['checkedOn'], 'defaultRule': limits.get('defaultRuleText'),
           'species': out}, open('FishoDex/Resources/species.json', 'w'), indent=1, ensure_ascii=False)
print(len(out), 'species written')
