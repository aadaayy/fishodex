# FishoDex

A fishing dex for South Florida. Every fish you catch fills in its card: 63 freshwater, inshore and offshore fish, plus a bonus Trophy Florida bass card for a bass of 10 lb or more. Fish you haven't caught yet show as silhouettes. Each fish's page has a fun fact, what it is and where to find it, and Florida's size and bag limits.

You add a catch by name (nicknames like mangrove snapper work too) or from a photo. Photo ID looks at the photo right on the phone and shows the three fish it looks most like, with how sure it is. You tap the right one, or pick it by name, then add the date, the place, and the weight and length if you have them. Nothing unlocks until you save, so a wrong guess never unlocks the wrong fish.

Everything stays on the phone. There are no accounts and nothing goes to a server.

## What's in it

1. **Dex:** all 64 cards in number order, rings to filter by water, a search box, your level and XP.
2. **Fish page:** the card (with a sunburst once caught), your stats, a fun fact, about the fish, Florida's rules with a link to FWC, and your catches of it.
3. **Log a catch:** Identify from photo (take one or choose one) or pick the fish by name, then details: date, place (typed, your location, or a dropped pin), weight and length (both optional), kept or released, a note and a photo. It shows what the catch is worth in XP before you save.
4. **Unlock:** a new fish flips its card over, with confetti, the XP, any level up and any new patches.
5. **Logbook:** every catch, newest first, and a map of your spots that only you can see.
6. **Profile:** level and title, XP to the next level, each water's ring, the five title patches, the nine badge patches and settings (units, saving photos to Photos, a backup file).

## XP and levels

1. A new species earns its card's rarity XP: Common 10, Uncommon 25, Rare 60, Trophy 120, Legendary 300.
2. A repeat catch earns 2 XP, and a new personal best (longer or heavier) adds 10.
3. A Florida bass of 10 lb or more earns 120 XP, or 240 the first time, when it unlocks the Trophy bass card.
4. There are 20 levels. Reaching level n takes 10 × n × (n − 1) XP (level 5 is 200, level 10 is 900, level 20 is 3,800). Title patches come at levels 1, 5, 10, 15 and 20: Deckhand, Weekend Angler, Guide, Captain and Legend.
5. Badge patches: First Catch, Ten Species, Freshwater, Inshore and Offshore Master, Grand Slam (tarpon, bonefish and permit in one day), Inshore Slam (snook, redfish and seatrout in one day), Invader Hunter (a fish that isn't native to Florida) and Catch and Release (ten fish let go).

## Layouts

1. **iPhone 18 Pro and Pro Max:** upright, with a bottom bar and a big round Log button.
2. **Folded iPhone Duo:** the side bar on the right with Dex, Log, Logbook and Profile.
3. **Open iPhone Duo:** a rail on the left, the tab on the left half and the fish's page (or Log a catch) on the right half.

## How the code is laid out

1. `FishoDex/Core`: the fish catalog, catches, XP, levels, patches and units. Plain Swift with no screens, tested on Linux with `swift test`.
2. `FishoDex/Store`: saving catches and photos on the phone.
3. `FishoDex/Views` and `FishoDex/App`: the SwiftUI screens.
4. `FishoDex/Resources`: `species.json` (the 63 fish with facts and rules), the card art, and the fonts (Lilita One and Nunito, SIL Open Font License).
5. `Tests/FishoDexCoreTests`: the logic tests.
6. `FishoDexUITests`: the walk-through that uses the app on the simulators and takes the screenshots.
7. `Tools`: `make_assets.py` builds the image sets from the fish art, and `build_species.py` builds `species.json` from the fact and rules notes.
8. `Tools/photo_id`: how the photo ID model is built (see below).

## Photo ID

1. The model is `FishoDex/Resources/FishID.mlpackage` (about 22 MB). It runs on the phone with no internet, and the photo never leaves the phone.
2. It is Meta's DINOv2 small image model (Apache 2.0 license) with a FishoDex layer trained on top. It beat Apple's built-in Create ML image model on the same test photos; both results are in `Tools/photo_id/REPORT.md`.
3. It learned from openly licensed photos only: CC0, public domain, CC BY and CC BY-SA, from Wikimedia Commons and from museum and survey records on GBIF. iNaturalist photos are left out, including copies posted elsewhere, because iNaturalist's terms don't allow training AI on its data. Every photo and its photographer is listed in `Tools/photo_id/CREDITS.md`. The photos themselves are not in the app.
4. 15 fish had too few openly licensed photos to learn from yet (listed at the top of `Tools/photo_id/REPORT.md`). They don't come up as guesses, but you can always pick them by name.
5. The **Photo ID model** workflow on GitHub Actions rebuilds it: `collect.py` gathers and checks the photos, `probe.py` builds the DINOv2 model, `Train.swift` builds the Create ML model and tests both through Vision on a Mac, and `report.py` writes the report. Settings for a run are in `Tools/photo_id/run.json`.
6. The UI test photo `FishoDexUITests/scan-sample-bass.jpg` is "Largemouth bass 01.jpg" by the U.S. Fish and Wildlife Service, public domain, from Wikimedia Commons.

Every push runs the checks on GitHub Actions. Screenshots from `main` go to the `screenshots` branch, and from other branches to `screenshots-<branch>`.

## Run it on your iPhone (free Apple account)

You need a Mac with Xcode 27.1 or later.

### First time

1. In Xcode, choose Integrate > Clone, paste `https://github.com/aadaayy/fishodex`, and pick a folder.
2. Open `FishoDex.xcodeproj` if it doesn't open by itself.
3. Xcode Settings > Accounts: sign in with your Apple account. A free account works; Xcode calls it a Personal Team.
4. Click the blue FishoDex project at the top of the file list, open Signing & Capabilities, and pick your Personal Team for the FishoDex target.
5. If Xcode says the bundle identifier is taken, change `com.albertoaday.fishodex` to something unique to you.
6. Plug the phone into the Mac with a cable and tap Trust on the phone. Developer Mode must be on (Settings > Privacy & Security > Developer Mode).
7. In Xcode, pick your phone from the device menu at the top and press Run (the play button).
8. The first time, the phone may block the app. Open Settings > General > VPN & Device Management, trust your developer certificate, and open the app again.

### Each time there's a new version

1. Integrate > Pull.
2. Press Run.

## Fishing rules

The limits on each fish's page were checked with the Florida Fish and Wildlife Conservation Commission (FWC) on November 6, 2026, and are written in our own words. Rules change, so each page links to FWC's own page for that fish.
