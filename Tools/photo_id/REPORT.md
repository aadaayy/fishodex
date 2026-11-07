# Photo ID model report

Photos: 1802 in 62 classes. Skipped while collecting: black and white 1577, cached 1678, download failed 40, duplicate 128, new 512, not a fish photo (seen before) 2408, not a fish photo: a beach or shoreline with no fish 1, not a fish photo: a car 5, not a fish photo: a concert or stage 3, not a fish photo: a cooked fish dish served on a plate 1, not a fish photo: a drawing or illustration of a fish 2, not a fish photo: a faded preserved fish specimen on a lab table with a ruler and label 141, not a fish photo: a fish preserved in a glass jar of alcohol 1, not a fish photo: a fish skeleton 13, not a fish photo: a landscape photo 5, not a fish photo: a page of text 1, not a fish photo: a photo of a bird 2, not a fish photo: a photo of a boat with no fish visible 30, not a fish photo: a photo of a coral reef with no fish 9, not a fish photo: a photo of dolphins, the marine mammals 2, not a fish photo: a photo of fresh fish on ice at a fish market 1, not a fish photo: a raw fish fillet or steak 4, not a fish photo: a statue, mascot or sculpture 1, not a fish photo: a taxidermy fish mounted on a wall 5, not a fish photo: a watercolor painting of a fish 2, not a fish photo: an old printed book plate of fish drawings 2, not a fish photo: an x-ray of a fish 2, not a fish photo: no fish in it 16, not an image 123, over the cap 11, too narrow 3, too small 161

Left out of the model (too few photos): mayan, acara, knifefish, gar, whitecat, bonefish, blackdrum, ladyfish, spanishmack, gafftop, sailfish, kingmack, blackfin, littletunny, bluemarlin

| Model | Fit | Test photos | Top 1 | Top 3 | ms a photo | Size |
|---|---|---|---|---|---|---|
| Create ML scene print | centerCrop | 265 | 67.2% | 80.0% | 73 | 0.3 MB |
| Create ML scene print | scaleFit | 265 | 63.8% | 74.0% | 71 | 0.3 MB |
| Create ML scene print | scaleFill | 265 | 69.4% | 81.5% | 86 | 0.3 MB |
| DINOv2 small probe | centerCrop | 265 | 84.5% | 92.1% | 24 | 22.0 MB |
| DINOv2 small probe | scaleFit | 265 | 79.2% | 89.4% | 16 | 22.0 MB |
| DINOv2 small probe | scaleFill | 265 | 83.4% | 92.1% | 14 | 22.0 MB |

Create ML scene print: training error 0.015, validation error 0.338, 120 iterations, 442 s.

Best: DINOv2 small probe, fit centerCrop. How sure the first guess was, and how often it was right:

- at least 30% sure: 98% of photos, right 85% of the time
- at least 50% sure: 90% of photos, right 90% of the time
- at least 70% sure: 78% of photos, right 96% of the time
- at least 85% sure: 72% of photos, right 98% of the time

| Fish | Photos (train/test) | Top 1 | Top 3 |
|---|---|---|---|
| Florida bass (bass) | 105/18 | 18/18 | 18/18 |
| Butterfly peacock bass (peacock) | 8/2 | 2/2 | 2/2 |
| Sunshine bass (sunshine) | 31/6 | 5/6 | 6/6 |
| Bluegill (bluegill) | 51/9 | 7/9 | 9/9 |
| Redear sunfish (redear) | 12/2 | 0/2 | 0/2 |
| Spotted sunfish (spottedsun) | 5/1 | 0/1 | 0/1 |
| Warmouth (warmouth) | 11/2 | 0/2 | 2/2 |
| Black crappie (crappie) | 18/3 | 2/3 | 2/3 |
| Chain pickerel (pickerel) | 10/2 | 2/2 | 2/2 |
| Mayan cichlid (mayan) | 3/1 | - | - |
| Oscar (oscar) | 132/23 | 22/23 | 23/23 |
| Jaguar guapote (jaguar) | 14/3 | 3/3 | 3/3 |
| Midas cichlid (midas) | 25/4 | 3/4 | 4/4 |
| Black acara (acara) | 1/0 | - | - |
| Blue tilapia (bluetilapia) | 6/1 | 1/1 | 1/1 |
| Spotted tilapia (spottedtilapia) | 7/1 | 0/1 | 1/1 |
| Snakehead (snakehead) | 11/2 | 2/2 | 2/2 |
| Clown knifefish (knifefish) | 3/1 | - | - |
| Florida gar (gar) | 2/0 | - | - |
| Bowfin (bowfin) | 8/1 | 0/1 | 0/1 |
| Channel catfish (channelcat) | 60/10 | 10/10 | 10/10 |
| White catfish (whitecat) | 2/0 | - | - |
| Walking catfish (walkingcat) | 16/3 | 3/3 | 3/3 |
| Common snook (snook) | 11/2 | 1/2 | 2/2 |
| Tarpon (tarpon) | 14/3 | 1/3 | 1/3 |
| Redfish (redfish) | 17/3 | 2/3 | 2/3 |
| Spotted seatrout (seatrout) | 10/2 | 2/2 | 2/2 |
| Bonefish (bonefish) | 3/1 | - | - |
| Permit (permit) | 5/1 | 0/1 | 0/1 |
| Gray snapper (graysnapper) | 19/3 | 1/3 | 1/3 |
| Lane snapper (lanesnapper) | 6/1 | 0/1 | 0/1 |
| Mutton snapper (muttonsnapper) | 8/1 | 0/1 | 1/1 |
| Sheepshead (sheepshead) | 8/2 | 2/2 | 2/2 |
| Black drum (blackdrum) | 4/1 | - | - |
| Crevalle jack (crevalle) | 14/3 | 2/3 | 2/3 |
| Ladyfish (ladyfish) | 4/1 | - | - |
| Florida pompano (pompano) | 26/5 | 5/5 | 5/5 |
| Spanish mackerel (spanishmack) | 4/1 | - | - |
| Great barracuda (barracuda) | 54/9 | 8/9 | 9/9 |
| Bluefish (bluefish) | 20/4 | 3/4 | 3/4 |
| Gafftopsail catfish (gafftop) | 0/0 | - | - |
| Lookdown (lookdown) | 34/6 | 6/6 | 6/6 |
| Goliath grouper (goliath) | 9/2 | 2/2 | 2/2 |
| Mahi-mahi (mahi) | 28/5 | 3/5 | 4/5 |
| Sailfish (sailfish) | 4/1 | - | - |
| King mackerel (kingmack) | 3/1 | - | - |
| Wahoo (wahoo) | 7/1 | 1/1 | 1/1 |
| Blackfin tuna (blackfin) | 0/0 | - | - |
| Yellowfin tuna (yellowfin) | 53/9 | 9/9 | 9/9 |
| Little tunny (littletunny) | 4/1 | - | - |
| Cobia (cobia) | 5/1 | 0/1 | 1/1 |
| Greater amberjack (amberjack) | 57/10 | 9/10 | 10/10 |
| Almaco jack (almaco) | 26/5 | 2/5 | 3/5 |
| African pompano (africanpompano) | 14/3 | 2/3 | 3/3 |
| Yellowtail snapper (yellowtail) | 26/5 | 4/5 | 4/5 |
| Vermilion snapper (vermilion) | 55/10 | 10/10 | 10/10 |
| Red grouper (redgrouper) | 19/3 | 3/3 | 3/3 |
| Black grouper (blackgrouper) | 12/2 | 1/2 | 2/2 |
| Hogfish (hogfish) | 20/3 | 2/3 | 3/3 |
| Gray triggerfish (trigger) | 47/8 | 8/8 | 8/8 |
| Lionfish (lionfish) | 153/27 | 27/27 | 27/27 |
| Blue marlin (bluemarlin) | 2/0 | - | - |
| Swordfish (swordfish) | 60/11 | 11/11 | 11/11 |
| Not in the dex (other) | 122/22 | 17/22 | 19/22 |

Most common mix-ups (truth -> first guess):

- almaco -> other: 2
- graysnapper -> bass: 2
- other -> yellowfin: 2
- tarpon -> snook: 2
- warmouth -> bluegill: 2
- africanpompano -> lookdown: 1
- almaco -> amberjack: 1
- amberjack -> yellowfin: 1
- barracuda -> bluefish: 1
- blackgrouper -> other: 1
- bluefish -> amberjack: 1
- bluegill -> channelcat: 1
- bluegill -> other: 1
- bowfin -> other: 1
- cobia -> channelcat: 1
- crappie -> seatrout: 1
- crevalle -> pompano: 1
- hogfish -> other: 1
- lanesnapper -> muttonsnapper: 1
- mahi -> yellowfin: 1

DINOv2 probe in Python before conversion (centerCrop): top 1 84.2%, top 3 92.5%, C=0.1.
