import SwiftUI

/// Your angler card: level and title, XP, how much of each water you've
/// caught, the title patches, the ten badge patches (Rookie included) and the settings.
struct ProfileView: View {
    @Environment(CatchStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("Profile").font(Fonts.title(32, relativeTo: .largeTitle)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.6)
                    Spacer()
                }
                LevelCard()
                StatsRow()
                WatersPanel()
                TitlesPanel()
                BadgesPanel()
                StarterPanel()
                SettingsPanel()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(WaterBackground())
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// The level patch, the title and the XP to the next level.
struct LevelCard: View {
    @Environment(CatchStore.self) private var store

    var body: some View {
        let p = store.progress
        let level = p.level
        HStack(spacing: 14) {
            PatchView(shape: .shield, text: "\(level)", earned: true, color: Palette.sun, size: 82)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Level \(level)")
                    .font(Fonts.body(13, .black, relativeTo: .caption))
                    .foregroundStyle(Palette.muted)
                Text(p.title)
                    .font(Fonts.title(28))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                XPBar(fraction: Leveling.fraction(for: p.totalXP))
                Text(nextText(xp: p.totalXP, level: level))
                    .font(Fonts.body(13, .extraBold))
                    .foregroundStyle(Palette.ink)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("level-card")
    }

    private func nextText(xp: Int, level: Int) -> String {
        guard level < Leveling.maxLevel else { return "\(xp) XP. Top level reached." }
        let needed = Leveling.xpToReach(level + 1) - xp
        return "\(xp) XP. \(needed) more to level \(level + 1)."
    }
}

struct StatsRow: View {
    @Environment(CatchStore.self) private var store

    var body: some View {
        let p = store.progress
        HStack(spacing: 10) {
            StatTile(title: "Species", value: "\(p.caught.count) of \(store.catalog.species.count)")
            StatTile(title: "Catches", value: "\(store.catches.count)")
            StatTile(title: "Released", value: "\(store.catches.filter(\.released).count)")
        }
    }
}

/// One ring for each water.
struct WatersPanel: View {
    @Environment(CatchStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(text: "Your waters", symbol: "drop.fill")
            HStack(spacing: 8) {
                ForEach(Habitat.allCases, id: \.self) { h in
                    let all = store.catalog.species(in: h)
                    let caught = store.progress.caughtCount(in: all)
                    VStack(spacing: 6) {
                        ZStack {
                            Ring(fraction: all.isEmpty ? 0 : Double(caught) / Double(all.count), color: h.color, line: 9)
                            Image(systemName: h.symbol)
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundStyle(Palette.ink)
                        }
                        .frame(width: 66, height: 66)
                        Text(h.rawValue)
                            .font(Fonts.body(13, .black))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if store.homeWater == h {
                            Pill(text: "Home", fill: Palette.sun, size: 10)
                                .accessibilityLabel("Home water")
                        }
                        Text("\(caught) of \(all.count)")
                            .font(Fonts.body(13, .bold))
                            .foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker()
    }
}

/// The starter quests from the first-launch tour: the starter card once
/// it's flipped, the quests done, and a button to play the tour again.
struct StarterPanel: View {
    @Environment(CatchStore.self) private var store
    @Environment(AppModel.self) private var model

    var body: some View {
        let done = store.starterQuests.count
        let all = StarterQuest.allCases.count
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(text: "Starter quests", symbol: "flag.checkered")
                Spacer()
                Text("\(done) of \(all)")
                    .font(Fonts.body(14, .black))
                    .foregroundStyle(Palette.ink)
            }
            HStack(alignment: .center, spacing: 14) {
                Group {
                    if store.starterQuests.contains(.starterCard) {
                        StarterCardFace()
                    } else {
                        CardBack()
                    }
                }
                .frame(width: 72, height: 94)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(done == all ? "All done. You earned \(Starter.totalXP) starter XP and the Rookie patch."
                                     : "\(Starter.xp(for: store.starterQuests)) of \(Starter.totalXP) starter XP earned. Finish the tour for the rest and the Rookie patch.")
                        .font(Fonts.body(14, .bold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        model.walkthrough = true
                    } label: {
                        Label(done == all ? "Replay the tour" : "Finish the tour", systemImage: "play.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: done == all ? Palette.sun : Palette.orange,
                                                   text: done == all ? Palette.ink : .white, size: 16))
                    .accessibilityIdentifier("replay-walkthrough")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("starter-panel")
    }
}

/// The five title patches, earned at levels 1, 5, 10, 15 and 20.
struct TitlesPanel: View {
    @Environment(CatchStore.self) private var store

    var body: some View {
        let level = store.progress.level
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(text: "Title patches", symbol: "rosette")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4, alignment: .top), count: 5), spacing: 8) {
                ForEach(Leveling.titles, id: \.level) { t in
                    let earned = level >= t.level
                    VStack(spacing: 6) {
                        PatchView(shape: .circle, text: "\(t.level)", earned: earned,
                                  color: earned ? Palette.sun : Palette.paperShade, size: 44)
                        Text(t.title)
                            .font(Fonts.body(11, .black, relativeTo: .caption))
                            .foregroundStyle(earned ? Palette.ink : Palette.muted)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(t.title), level \(t.level), \(earned ? "earned" : "locked")")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker()
    }
}

/// The ten badge patches with how close you are to each.
struct BadgesPanel: View {
    @Environment(CatchStore.self) private var store

    var body: some View {
        let earned = store.badges.filter(\.earned).count
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(text: "Badge patches", symbol: "star.fill")
                Spacer()
                Text("\(earned) of \(store.badges.count)")
                    .font(Fonts.body(14, .black))
                    .foregroundStyle(Palette.ink)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10, alignment: .top)], spacing: 14) {
                ForEach(store.badges) { badge in
                    BadgeCell(badge: badge)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("badges-panel")
    }
}

struct BadgeCell: View {
    var badge: Badge

    var body: some View {
        VStack(spacing: 5) {
            PatchView(shape: badge.shape, symbol: badge.symbol, earned: badge.earned, color: color, size: 62)
            Text(badge.name)
                .font(Fonts.body(13, .black))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(badge.detail)
                .font(Fonts.body(11, .bold, relativeTo: .caption))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(badge.progressText)
                .font(Fonts.body(11, .black, relativeTo: .caption))
                .foregroundStyle(badge.earned ? Palette.ink : Palette.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(badge.earned ? Palette.good : Palette.paperShade))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("badge-\(badge.id)")
    }

    private var color: Color {
        switch badge.id {
        case "freshwater": return Habitat.freshwater.color
        case "inshore": return Habitat.inshore.color
        case "offshore": return Habitat.offshore.color
        case "grandslam", "inshoreslam": return Palette.sun
        case "invader": return Color(hex: 0xE5484D)
        case "release": return Palette.waterLight
        default: return Palette.orange
        }
    }
}

/// Units, photos, your spots, a backup file and the small print.
struct SettingsPanel: View {
    @Environment(CatchStore.self) private var store
    @State private var backup: URL?

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 14) {
            PanelTitle(text: "Settings", symbol: "gearshape.fill")

            VStack(alignment: .leading, spacing: 6) {
                Text("Units").font(Fonts.body(14, .black)).foregroundStyle(Palette.ink)
                StickerSegmented(title: "Units", selection: $store.units,
                                 options: [("lb and in", UnitSystem.us), ("kg and cm", UnitSystem.metric)])
                .accessibilityIdentifier("units-picker")
            }

            Toggle(isOn: $store.saveToPhotos) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save catch photos to Photos").font(Fonts.body(15, .extraBold))
                    Text("Photos always stay on this phone.").font(Fonts.body(13, .bold)).foregroundStyle(Palette.muted)
                }
            }
            .tint(Palette.good)
            .foregroundStyle(Palette.ink)
            .accessibilityIdentifier("photos-toggle")

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.fill").font(.system(size: 16, weight: .heavy))
                Text("Your spots are private. Places and map pins are saved on this phone only, and nothing is shared.")
                    .font(Fonts.body(14, .bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Palette.ink)

            if let backup {
                ShareLink(item: backup) {
                    Label("Share backup file", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(ChunkyButtonStyle(fill: Palette.sun, text: Palette.ink, size: 17, expand: true))
                .accessibilityIdentifier("share-backup")
            } else {
                Button {
                    backup = store.exportFile()
                } label: {
                    Label("Make a backup file", systemImage: "externaldrive.fill")
                }
                .buttonStyle(ChunkyButtonStyle(fill: Palette.sun, text: Palette.ink, size: 17, expand: true))
                .disabled(store.catches.isEmpty)
                .accessibilityIdentifier("make-backup")
            }

            Divider().overlay(Palette.ink.opacity(0.3))

            Text("Fishing rules change. The limits on each fish's page were checked with the Florida Fish and Wildlife Conservation Commission (FWC). Always check the current rules before you keep a fish.")
                .font(Fonts.body(13, .bold))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text("Photo ID works on this phone and is a guess, so check the fish before you save. It learned from openly licensed photos on Wikimedia Commons and from museum and survey collections, listed with their photographers in FishoDex's code.")
                .font(Fonts.body(12, .bold, relativeTo: .caption))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text("Fonts: Lilita One and Nunito, under the SIL Open Font License. Fish art drawn for FishoDex.")
                .font(Fonts.body(12, .bold, relativeTo: .caption))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text("FishoDex \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                .font(Fonts.body(12, .bold, relativeTo: .caption))
                .foregroundStyle(Palette.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker()
        .onChange(of: store.catches.count) { backup = nil }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-panel")
    }
}
