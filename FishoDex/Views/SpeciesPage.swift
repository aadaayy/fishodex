import SwiftUI

/// A fish's page: the big card, your stats, a fun fact, what it is, where to
/// find it, Florida's rules and your catches of it.
struct SpeciesPage: View {
    @Environment(CatchStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.layoutShape) private var layout
    var card: DexCard

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                switch card {
                case .species(let s): speciesContent(s)
                case .trophyBass: trophyContent()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(WaterBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(title).font(Fonts.title(20)).foregroundStyle(Palette.ink)
            }
        }
        .tint(Palette.ink)
    }

    private var title: String {
        switch card {
        case .species(let s): return s.numberText
        case .trophyBass: return "Bonus card"
        }
    }

    // MARK: A species

    @ViewBuilder
    private func speciesContent(_ s: Species) -> some View {
        let caught = store.progress.caught.contains(s.id)
        BigCard(image: caught ? "card-\(s.id)" : "sil-\(s.id)", rarity: s.rarity, glowing: caught)
            .accessibilityLabel("\(s.name) card, \(caught ? "caught" : "not caught yet")")
            .accessibilityIdentifier("big-card")

        if caught {
            HStack(spacing: 10) {
                StatTile(title: "Caught", value: "\(store.progress.catchCount[s.id] ?? 0)")
                StatTile(title: "Biggest", value: store.biggestText(for: s.id) ?? "None")
                StatTile(title: "XP earned", value: "\(store.progress.xpBySpecies[s.id] ?? 0)")
            }
        } else {
            NotCaughtPanel(xp: s.rarity.newSpeciesXP, rarity: s.rarity) { model.startLog(preset: s.id) }
        }

        SeasonNowPanel(species: s)

        FunFactPanel(text: s.funFact)

        InfoPanel(title: "About", symbol: "book.fill") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Pill(text: s.rarity.rawValue, fill: s.rarity.color)
                    Pill(text: s.habitat.rawValue, fill: s.habitat.color, textColor: Palette.ink)
                    if s.nonNative { Pill(text: "Not native", fill: Palette.paperShade) }
                }
                Text(s.name).font(Fonts.title(24)).foregroundStyle(Palette.ink)
                Text(s.scientific).font(Fonts.body(15, .bold)).italic().foregroundStyle(Palette.muted)
                BodyText(s.about)
                if let max = s.maxSize { LabeledLine(label: "Size", value: max) }
                LabeledLine(label: "Where to find it", value: s.whereToFind)
            }
        }

        if let limits = s.limits { RulesPanel(limits: limits, checkedOn: store.catalog.limitsCheckedOn) }

        if s.id == SpeciesCatalog.floridaBassID {
            TrophyHint(unlocked: store.progress.hasTrophyBass)
        }

        YourCatches(catches: store.catches(of: s.id))
    }

    // MARK: The Trophy bass

    @ViewBuilder
    private func trophyContent() -> some View {
        let unlocked = store.progress.hasTrophyBass
        BigCard(image: unlocked ? "card-trophybass" : "sil-trophybass", rarity: .trophy, glowing: unlocked)
            .accessibilityLabel("Trophy Florida bass card, \(unlocked ? "unlocked" : "locked")")
            .accessibilityIdentifier("big-card")
        InfoPanel(title: "Trophy Florida bass", symbol: "trophy.fill") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Pill(text: "Bonus", fill: Rarity.trophy.color, textColor: .white)
                    Pill(text: "10 lb+", fill: Palette.sun)
                }
                BodyText("Log a Florida bass that weighs 10 pounds or more to unlock this card. Length alone doesn't count, so weigh it.")
                BodyText("The first one earns 240 XP, double the Trophy XP. Every one after that earns 120. It's a bonus card, so the dex still counts 63 fish without it.")
                if unlocked {
                    LabeledLine(label: "Trophy bass logged", value: "\(store.progress.trophyBassCount)")
                }
            }
        }
        if !unlocked {
            Button("Log a bass") { model.startLog(preset: SpeciesCatalog.floridaBassID) }
                .buttonStyle(ChunkyButtonStyle(expand: true))
        }
        YourCatches(catches: store.trophyBassCatches)
    }
}

// MARK: Pieces

struct BigCard: View {
    var image: String
    var rarity: Rarity
    var glowing: Bool
    @State private var spin = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var still: Bool { reduceMotion || LaunchOptions.current.still }

    var body: some View {
        Image(image)
            .resizable()
            .aspectRatio(600 / 780, contentMode: .fit)
            .frame(maxWidth: 290)
            .shadow(color: Palette.ink.opacity(0.35), radius: 0, x: 0, y: 6)
            .frame(maxWidth: .infinity)
            .frame(height: 380)
            .background {
                // The sunburst sits behind the card and never widens the page.
                if glowing {
                    Sunburst(color: rarity.color.opacity(0.55))
                        .frame(width: 420, height: 420)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                        .animation(still ? nil : .linear(duration: 60).repeatForever(autoreverses: false), value: spin)
                        .onAppear { if !still { spin = true } }
                        .accessibilityHidden(true)
                }
            }
            .clipped()
    }
}

struct Sunburst: View {
    var color: Color
    var rays = 18

    var body: some View {
        Canvas { context, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = max(size.width, size.height)
            for i in 0..<rays {
                let a0 = Double(i) / Double(rays) * 2 * .pi
                let a1 = a0 + .pi / Double(rays)
                var p = Path()
                p.move(to: c)
                p.addLine(to: CGPoint(x: c.x + r * cos(a0), y: c.y + r * sin(a0)))
                p.addLine(to: CGPoint(x: c.x + r * cos(a1), y: c.y + r * sin(a1)))
                p.closeSubpath()
                context.fill(p, with: .color(color))
            }
        }
        .mask(RadialGradient(colors: [.black, .black.opacity(0)], center: .center, startRadius: 60, endRadius: 210))
    }
}

struct StatTile: View {
    var title: String
    var value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Fonts.title(20))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(title.uppercased())
                .font(Fonts.body(11, .black, relativeTo: .caption))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .sticker(radius: 14, lift: 4)
        .accessibilityElement(children: .combine)
    }
}

struct NotCaughtPanel: View {
    var xp: Int
    var rarity: Rarity
    var onLog: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "questionmark")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Palette.night2))
                    .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Not caught yet").font(Fonts.title(20)).foregroundStyle(.white)
                    Text("Your first one is worth \(xp) XP.")
                        .font(Fonts.body(15, .extraBold))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            Button("Log this fish", action: onLog)
                .buttonStyle(ChunkyButtonStyle(expand: true))
                .accessibilityIdentifier("log-this-fish")
        }
        .padding(14)
        .sticker(Palette.night)
    }
}

struct FunFactPanel: View {
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Pill(text: "Fun fact", fill: .white)
                Spacer()
                Image(systemName: "sparkles").font(.system(size: 20, weight: .heavy)).foregroundStyle(Palette.ink)
            }
            Text(text)
                .font(Fonts.body(17, .extraBold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(Palette.sun)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("fun-fact")
    }
}

struct InfoPanel<Content: View>: View {
    var title: String
    var symbol: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelTitle(text: title, symbol: symbol)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker()
    }
}

struct BodyText: View {
    var text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Fonts.body(16, .bold))
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct LabeledLine: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(Fonts.body(11, .black, relativeTo: .caption))
                .foregroundStyle(Palette.muted)
            Text(value)
                .font(Fonts.body(16, .extraBold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Florida's size and bag limits, with the date they were checked and a link to FWC.
struct RulesPanel: View {
    @Environment(\.openURL) private var openURL
    var limits: FishLimits
    var checkedOn: String

    var body: some View {
        InfoPanel(title: "Florida rules", symbol: "checkmark.shield.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Pill(text: limits.headline, fill: headlineColor, textColor: Palette.ink)
                if let size = limits.size { LabeledLine(label: "Size", value: size) }
                if let bag = limits.bag { LabeledLine(label: "Bag limit", value: bag) }
                if let season = limits.season { LabeledLine(label: "Season", value: season) }
                if let areas = limits.areas, !areas.isEmpty {
                    ForEach(areas, id: \.self) { a in LabeledLine(label: a.area, value: a.text) }
                }
                if let notes = limits.notes {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill").foregroundStyle(Palette.orange)
                        BodyText(notes)
                    }
                }
                Text("Checked with FWC on \(checkedText). Rules change, so check before you keep a fish.")
                    .font(Fonts.body(13, .bold))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let link = limits.url.flatMap(URL.init(string:)) {
                    Button {
                        openURL(link)
                    } label: {
                        Label("Check current rules", systemImage: "arrow.up.right.square.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.paper, text: Palette.ink, size: 17, expand: true))
                    .accessibilityIdentifier("check-rules")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("rules-panel")
    }

    private var headlineColor: Color {
        switch limits.kind {
        case "release": return Palette.good
        case "prohibited": return Palette.orange
        case "none": return Palette.paperShade
        default: return Palette.sun
        }
    }

    private var checkedText: String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        input.locale = Locale(identifier: "en_US_POSIX")
        guard let date = input.date(from: checkedOn) else { return checkedOn }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct TrophyHint: View {
    @Environment(AppModel.self) private var model
    var unlocked: Bool

    var body: some View {
        Button {
            if model.selected != .trophyBass { model.selected = .trophyBass }
            model.dexPath.append(.trophyBass)
        } label: {
            HStack(spacing: 12) {
                Image("sil-trophybass")
                    .resizable().aspectRatio(600 / 780, contentMode: .fit).frame(width: 44)
                    .opacity(unlocked ? 0 : 1)
                    .overlay { if unlocked { Image("card-trophybass").resizable().aspectRatio(600 / 780, contentMode: .fit) } }
                VStack(alignment: .leading, spacing: 2) {
                    Text(unlocked ? "Trophy bass unlocked" : "Trophy bass: 10 lb or more")
                        .font(Fonts.title(18)).foregroundStyle(Palette.ink)
                    Text(unlocked ? "See your bonus card." : "Log a bass of 10 pounds or more to unlock a bonus card.")
                        .font(Fonts.body(14, .bold)).foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .black)).foregroundStyle(Palette.ink)
            }
            .padding(12)
            .sticker(Rarity.trophy.color.opacity(0.25))
        }
        .buttonStyle(.plain)
    }
}

/// Your catches of this fish, newest first.
struct YourCatches: View {
    @Environment(CatchStore.self) private var store
    var catches: [Catch]

    var body: some View {
        if !catches.isEmpty {
            InfoPanel(title: "Your catches", symbol: "list.bullet") {
                VStack(spacing: 8) {
                    ForEach(catches) { c in
                        NavigationLink {
                            CatchDetailView(catchID: c.id)
                        } label: {
                            CatchRow(item: c, showFish: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
