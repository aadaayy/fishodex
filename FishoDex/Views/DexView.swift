import SwiftUI

/// The dex: every fish as a numbered card. Caught fish show their art,
/// fish not caught yet show a silhouette. Rings filter by water.
struct DexView: View {
    @Environment(CatchStore.self) private var store
    var onSelect: (DexCard) -> Void

    @State private var habitat: Habitat?
    @State private var query = ""

    private var cards: [DexCard] {
        var out: [DexCard] = []
        for s in store.catalog.search(query, habitat: habitat) {
            out.append(.species(s))
            if s.id == SpeciesCatalog.floridaBassID, query.isEmpty || "trophy".contains(query.lowercased()) {
                out.append(.trophyBass)
            }
        }
        return out
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                DexHeader()
                EventBanner()
                HabitatFilter(selection: $habitat)
                SearchField(text: $query, prompt: "Search the dex")
                let list = cards
                if list.isEmpty {
                    Text("No fish match \"\(query)\".")
                        .font(Fonts.body(16, .extraBold))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .sticker()
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 170), spacing: 10)], spacing: 10) {
                        ForEach(list) { card in
                            Button { onSelect(card) } label: { DexCardView(card: card) }
                                .buttonStyle(CardPressStyle())
                                .accessibilityIdentifier("card-\(card.id)")
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(WaterBackground())
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// The title, your level and XP, and how many fish you've caught.
struct DexHeader: View {
    @Environment(CatchStore.self) private var store

    var body: some View {
        let p = store.progress
        let total = store.catalog.species.count
        VStack(alignment: .leading, spacing: 8) {
            // Title and count side by side, the count under it when big text won't fit both.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    title.fixedSize()
                    Spacer(minLength: 8)
                    count(p, total).fixedSize()
                }
                VStack(alignment: .leading, spacing: 2) {
                    title.lineLimit(1).minimumScaleFactor(0.6)
                    count(p, total)
                }
            }
            // Side by side when there's room, the XP on its own line when not.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    levelLine(p)
                    Spacer(minLength: 4)
                    xpLine(p)
                }
                VStack(alignment: .leading, spacing: 4) {
                    levelLine(p)
                    xpLine(p)
                }
            }
            XPBar(fraction: Leveling.fraction(for: p.totalXP))
        }
        .padding(14)
        .sticker()
        .accessibilityElement(children: .combine)
    }

    private var title: some View {
        Text("FishoDex")
            .font(Fonts.title(32, relativeTo: .largeTitle))
            .foregroundStyle(Palette.ink)
    }

    private func count(_ p: DexProgress, _ total: Int) -> some View {
        Text("\(p.caught.count) / \(total)")
            .font(Fonts.title(22))
            .foregroundStyle(Palette.ink)
            .accessibilityLabel("\(p.caught.count) of \(total) fish caught")
    }

    private func levelLine(_ p: DexProgress) -> some View {
        // The title sits beside the level pill, or under it when big text won't fit both.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Pill(text: "Lv \(p.level)", fill: Palette.sun).fixedSize()
                levelTitle(p).fixedSize()
            }
            VStack(alignment: .leading, spacing: 4) {
                Pill(text: "Lv \(p.level)", fill: Palette.sun).fixedSize()
                levelTitle(p)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func levelTitle(_ p: DexProgress) -> some View {
        Text(p.title)
            .font(Fonts.body(15, .black))
            .foregroundStyle(Palette.ink)
    }

    private func xpLine(_ p: DexProgress) -> some View {
        Text(xpText(p))
            .font(Fonts.body(13, .extraBold))
            .foregroundStyle(Palette.muted)
            .lineLimit(1)
            .fixedSize()
    }

    private func xpText(_ p: DexProgress) -> String {
        p.level >= Leveling.maxLevel ? "\(p.totalXP) XP" : "\(p.totalXP) / \(Leveling.xpToReach(p.level + 1)) XP"
    }
}

/// All / Freshwater / Inshore / Offshore, each with its completion ring.
struct HabitatFilter: View {
    @Environment(CatchStore.self) private var store
    @Binding var selection: Habitat?

    var body: some View {
        HStack(spacing: 8) {
            chip(nil, title: "All", color: Palette.sun,
                 caught: store.progress.caught.count, total: store.catalog.species.count)
            ForEach(Habitat.allCases) { h in
                let list = store.catalog.species(in: h)
                chip(h, title: h.rawValue, color: h.color,
                     caught: store.progress.caughtCount(in: list), total: list.count)
            }
        }
        // Four chips share one row, so they stop growing past xxxLarge.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func chip(_ h: Habitat?, title: String, color: Color, caught: Int, total: Int) -> some View {
        let on = selection == h
        return Button {
            withAnimation(.snappy) { selection = h }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Ring(fraction: total == 0 ? 0 : Double(caught) / Double(total), color: color, line: 6)
                        .frame(width: 38, height: 38)
                    Text("\(caught)").font(Fonts.title(14)).foregroundStyle(Palette.ink)
                }
                Text(title)
                    .font(Fonts.body(12, .black, relativeTo: .caption))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .sticker(on ? Palette.sun : Palette.paper, radius: 14, lift: on ? 2 : 4)
            .offset(y: on ? 2 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("filter-\(h?.rawValue.lowercased() ?? "all")")
        .accessibilityLabel("\(title), \(caught) of \(total) caught")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct SearchField: View {
    @Binding var text: String
    var prompt: String
    var identifier = "search-field"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Palette.muted)
            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Palette.muted))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier(identifier)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.muted)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .stickerField()
    }
}

/// One card in the grid: the approved art, or the silhouette.
struct DexCardView: View {
    @Environment(CatchStore.self) private var store
    var card: DexCard

    var body: some View {
        let caught = store.progress.isCaught(card)
        Image(caught ? "card-\(card.id)" : "sil-\(card.id)")
            .resizable()
            .aspectRatio(600 / 780, contentMode: .fit)
            .accessibilityLabel(label(caught: caught))
    }

    private func label(caught: Bool) -> String {
        switch card {
        case .species(let s): return "\(s.numberText) \(s.name), \(caught ? "caught" : "not caught yet")"
        case .trophyBass: return "Trophy Florida bass bonus card, \(caught ? "unlocked" : "locked, 10 pounds or more")"
        }
    }
}

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
