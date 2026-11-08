import SwiftUI

/// The first-launch tour, played as four starter quests. Each quest pays
/// 5 XP once (20 in all, exactly level 2), the bar fills as you go, and the
/// end hands out the Rookie patch. It asks for no permissions: the photo ID
/// and logging parts are practice, not the real camera or form.
/// Shown once on first launch; Profile can play it again (with no XP twice).
struct WalkthroughView: View {
    @Environment(CatchStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Page: Int, CaseIterable {
        case welcome, homeWater, starterCard, practiceLog, rules, finale
        var quest: StarterQuest? {
            switch self {
            case .homeWater: return .homeWater
            case .starterCard: return .starterCard
            case .practiceLog: return .practiceLog
            case .rules: return .rules
            case .welcome, .finale: return nil
            }
        }
    }

    @State private var page: Page = .welcome
    @State private var startLevel: Int?
    @State private var toast: Int?
    @State private var confetti = 0
    @State private var flipped = false
    @State private var quizPick: String?
    @State private var rulesPick: Bool?
    @State private var shake = 0

    private var still: Bool { reduceMotion || LaunchOptions.current.still }
    private var water: Habitat { store.homeWater ?? .inshore }

    var body: some View {
        ZStack {
            WaterBackground(deep: page == .finale)
                .onTapGesture {}
            VStack(spacing: 0) {
                if page != .finale { hud }
                ScrollView {
                    pageContent
                        .padding(.horizontal, 18)
                        .padding(.top, page == .finale ? 26 : 14)
                        .padding(.bottom, 16)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                        .id(page)
                }
                .scrollBounceBehavior(.basedOnSize)
                .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            }
            if confetti > 0 && !still {
                ConfettiView().id(confetti).allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) { xpToast }
        .onAppear {
            if startLevel == nil { startLevel = store.progress.level }
            flipped = store.starterQuests.contains(.starterCard)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walkthrough")
    }

    // MARK: Top: level, XP bar, quest stars and Skip

    private var hud: some View {
        let p = store.progress
        return HStack(spacing: 12) {
            PatchView(shape: .shield, text: "\(p.level)", earned: true, color: Palette.sun, size: 46)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Level \(p.level)").font(Fonts.body(14, .black))
                    Spacer(minLength: 6)
                    Text("\(p.totalXP) XP").font(Fonts.body(14, .black))
                        .accessibilityIdentifier("wt-xp")
                }
                .foregroundStyle(Palette.ink)
                XPBar(fraction: Leveling.fraction(for: p.totalXP), height: 14)
                    .animation(still ? nil : .easeOut(duration: 0.7), value: p.totalXP)
                HStack(spacing: 4) {
                    ForEach(StarterQuest.allCases) { q in
                        let done = store.starterQuests.contains(q)
                        Image(systemName: done ? "star.fill" : "star")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(done ? Palette.orange : Palette.muted)
                            .accessibilityHidden(true)
                    }
                    Text("\(store.starterQuests.count) of \(StarterQuest.allCases.count) quests")
                        .font(Fonts.body(12, .black, relativeTo: .caption))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            Button("Skip", action: close)
                .font(Fonts.body(15, .black))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Capsule().fill(Palette.paperShade).overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5)))
                .accessibilityLabel("Skip the tour")
                .accessibilityIdentifier("wt-skip")
        }
        // The top bar stays one size; the pages below grow with the text.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 560)
        .sticker(radius: 18, lift: 4)
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var xpToast: some View {
        if let xp = toast {
            Text("+\(xp) XP")
                .font(Fonts.title(26))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
                .sticker(Palette.sun, radius: 16, lift: 4)
                .padding(.top, 86)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
                .allowsHitTesting(false)
                .accessibilityIdentifier("wt-toast")
        }
    }

    // MARK: Pages

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case .welcome: welcome
        case .homeWater: homeWaterPage
        case .starterCard: starterCardPage
        case .practiceLog: practiceLogPage
        case .rules: rulesPage
        case .finale: finale
        }
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            CardFan()
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 10) {
                Pill(text: "Starter quests", fill: Palette.orange, textColor: .white)
                Text("Welcome aboard, angler!")
                    .font(Fonts.title(30, relativeTo: .largeTitle))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("wt-title")
                Text("Your dex has \(store.catalog.species.count + 1) cards. Each one stays a shadow until you catch that fish for real.")
                    .bodyText()
                Text("Clear four quick quests to learn the ropes and earn \(Starter.totalXP) starter XP.")
                    .bodyText()
                VStack(spacing: 8) {
                    ForEach(StarterQuest.allCases) { q in QuestRow(quest: q, done: store.starterQuests.contains(q)) }
                }
                .padding(.top, 2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sticker()
        }
    }

    private var homeWaterPage: some View {
        VStack(spacing: 14) {
            QuestHeader(number: 1, quest: .homeWater, done: store.starterQuests.contains(.homeWater),
                        title: "Where do you fish most?",
                        text: "Pick your home water. You can still catch fish in all three.")
            ForEach(Habitat.allCases) { h in
                WaterTile(habitat: h, count: store.catalog.species(in: h).count,
                          examples: Starter.shadows(for: h).compactMap { store.catalog[$0]?.name },
                          picked: store.homeWater == h) {
                    store.homeWater = h
                    earn(.homeWater)
                }
            }
        }
    }

    private var starterCardPage: some View {
        let done = store.starterQuests.contains(.starterCard)
        return VStack(spacing: 14) {
            QuestHeader(number: 2, quest: .starterCard, done: done,
                        title: "Every fish starts as a shadow",
                        text: "Log a real catch and that fish's card flips over. Try it on your starter card.")
            HStack(spacing: 10) {
                ForEach(Starter.shadows(for: water), id: \.self) { id in
                    Image("sil-\(id)")
                        .resizable()
                        .aspectRatio(600 / 780, contentMode: .fit)
                        .frame(maxWidth: 92)
                        .shadow(color: Palette.ink.opacity(0.35), radius: 0, x: 0, y: 3)
                        .accessibilityLabel("\(store.catalog[id]?.name ?? "Fish"), not caught yet")
                }
            }
            .frame(maxWidth: .infinity)
            Button(action: flip) {
                ZStack {
                    CardBack().opacity(flipped ? 0 : 1)
                    StarterCardFace()
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        .opacity(flipped ? 1 : 0)
                }
                .frame(width: 200, height: 260)
                .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .accessibilityLabel(flipped ? "Starter card, flipped" : "Starter card. Tap to flip it")
            .accessibilityIdentifier("wt-flip-card")
            Text(flipped ? "Starter card! It lives on your profile. Real fish cards flip just like this when you log them."
                         : "Tap the card to flip it.")
                .font(Fonts.body(16, .extraBold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity)
                .sticker(flipped ? Palette.sun : Palette.paper, radius: 14, lift: 4)
                .accessibilityIdentifier("wt-card-note")
        }
    }

    private var practiceLogPage: some View {
        let quiz = Starter.quiz(for: water)
        let done = store.starterQuests.contains(.practiceLog)
        let answerName = store.catalog[quiz.answer]?.name ?? ""
        return VStack(spacing: 14) {
            QuestHeader(number: 3, quest: .practiceLog, done: done,
                        title: "Two ways to log a catch",
                        text: "Tap the big orange Log button after every fish.")
            VStack(spacing: 10) {
                HowRow(symbol: "camera.viewfinder", title: "Photo ID",
                       text: "Take or choose a photo and FishoDex guesses the fish, right on your phone. You check it before saving.")
                HowRow(symbol: "character.cursor.ibeam", title: "By name",
                       text: "Type the fish's name, or the nickname you call it at the dock.")
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("PRACTICE")
                    .font(Fonts.body(12, .black, relativeTo: .caption))
                    .foregroundStyle(Palette.muted)
                Text("Your buddy calls it a \u{201C}\(quiz.nickname)\u{201D}. Which card is it?")
                    .font(Fonts.title(21, relativeTo: .headline))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(quiz.choices.enumerated()), id: \.element) { i, id in
                    let right = id == quiz.answer
                    let picked = quizPick == id || (done && right && quizPick == nil)
                    ChoiceButton(label: store.catalog[id]?.name ?? id, image: "sil-\(id)",
                                 state: picked ? (right ? .right : .wrong) : .plain) {
                        quizPick = id
                        if right { earn(.practiceLog) } else { nudge() }
                    }
                    .accessibilityIdentifier(right ? "wt-quiz-right" : "wt-quiz-wrong-\(i)")
                }
                if let pick = quizPick, pick != quiz.answer, !done {
                    Text("Not that one. Try again!")
                        .font(Fonts.body(15, .black))
                        .foregroundStyle(Color(hex: 0xC2362F))
                        .modifier(Shake(amount: still ? 0 : 6, shakes: CGFloat(shake)))
                }
                if done {
                    Text("Got it! Typing \u{201C}\(quiz.nickname)\u{201D} in Log finds the \(answerName.lowercased()).")
                        .bodyText()
                        .accessibilityIdentifier("wt-quiz-done")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sticker()
        }
    }

    private var rulesPage: some View {
        let done = store.starterQuests.contains(.rules)
        return VStack(spacing: 14) {
            QuestHeader(number: 4, quest: .rules, done: done,
                        title: "Seasons, events and limits",
                        text: "Events come back every year. Finish one for bonus XP and a limited card in the Events tab.")
            EventTeaser()
            VStack(alignment: .leading, spacing: 10) {
                Text("QUICK QUIZ")
                    .font(Fonts.body(12, .black, relativeTo: .caption))
                    .foregroundStyle(Palette.muted)
                Text("Snook season is closed and you catch one. When does it count toward an event?")
                    .font(Fonts.title(21, relativeTo: .headline))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                ChoiceButton(label: "When I keep it", symbol: "bag.fill",
                             state: rulesPick == false ? .wrong : .plain) {
                    rulesPick = false
                    nudge()
                }
                .accessibilityIdentifier("wt-rules-wrong")
                ChoiceButton(label: "When I let it go", symbol: "arrow.uturn.backward",
                             state: rulesPick == true || (done && rulesPick == nil) ? .right : .plain) {
                    rulesPick = true
                    earn(.rules)
                }
                .accessibilityIdentifier("wt-rules-right")
                if rulesPick == false && !done {
                    Text("Not quite. Try the other one!")
                        .font(Fonts.body(15, .black))
                        .foregroundStyle(Color(hex: 0xC2362F))
                        .modifier(Shake(amount: still ? 0 : 6, shakes: CGFloat(shake)))
                }
                if done {
                    Text("Right! A fish in a closed season only counts if you release it. Every fish's page shows Florida's size and bag limits too.")
                        .bodyText()
                        .accessibilityIdentifier("wt-rules-done")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sticker()
        }
    }

    private var finale: some View {
        let p = store.progress
        let leveledUp = p.level > (startLevel ?? p.level)
        let rookie = store.badges.first { $0.id == "rookie" }
        return VStack(spacing: 14) {
            Text("Starter quests done!")
                .font(Fonts.title(34, relativeTo: .largeTitle))
                .foregroundStyle(Palette.sun)
                .shadow(color: Palette.ink, radius: 0, x: 0, y: 3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("wt-finale-title")

            VStack(spacing: 12) {
                Text("+\(p.starterXP) starter XP")
                    .font(Fonts.title(34))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Level \(p.level)").font(Fonts.body(14, .black))
                        Spacer()
                        Text(p.title).font(Fonts.body(14, .black))
                    }
                    .foregroundStyle(Palette.ink)
                    XPBar(fraction: Leveling.fraction(for: p.totalXP), height: 18)
                }
                if leveledUp {
                    FinaleRow(patch: PatchView(shape: .shield, text: "\(p.level)", earned: true, color: Palette.sun, size: 54),
                              title: "Level up!", titleColor: Palette.orange,
                              text: "You're level \(p.level), \(p.title).")
                        .accessibilityIdentifier("wt-level-up")
                }
                if let rookie, rookie.earned {
                    FinaleRow(patch: PatchView(shape: rookie.shape, symbol: rookie.symbol, earned: true, color: Palette.orange, size: 54),
                              title: "Rookie patch", titleColor: Palette.ink,
                              text: "It's on your profile with your starter card.")
                        .accessibilityIdentifier("wt-rookie")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .sticker()

            VStack(alignment: .leading, spacing: 10) {
                PanelTitle(text: "Real fish earn way more", symbol: "bolt.fill")
                WrapLayout(spacing: 6) {
                    ForEach(Rarity.allCases) { r in
                        Pill(text: "\(r.rawValue) +\(r.newSpeciesXP)", fill: r.color, size: 12)
                    }
                }
                Text("A repeat catch is +\(ProgressEngine.repeatXP) and a new personal best is +\(ProgressEngine.personalBestXP). New title patches come at levels 5, 10, 15 and 20.")
                    .bodyText()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sticker()
        }
    }

    // MARK: Bottom buttons

    private var bottomBar: some View {
        VStack(spacing: 8) {
            switch page {
            case .welcome:
                Button("Start the quests") { go(.homeWater) }
                    .buttonStyle(ChunkyButtonStyle(expand: true))
                    .accessibilityIdentifier("wt-start")
                Button("Skip for now", action: close)
                    .font(Fonts.body(15, .black))
                    .foregroundStyle(Palette.ink)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("wt-skip-welcome")
            case .finale:
                Button {
                    close()
                    model.tab = .dex
                    model.startLog()
                } label: {
                    Label(store.catches.isEmpty ? "Log my first catch" : "Log a catch", systemImage: "plus")
                }
                .buttonStyle(ChunkyButtonStyle(expand: true))
                .accessibilityIdentifier("wt-finish-log")
                Button {
                    close()
                    model.tab = .dex
                } label: {
                    Label("Explore the dex", systemImage: "square.grid.3x3.fill")
                }
                .buttonStyle(ChunkyButtonStyle(fill: Palette.sun, text: Palette.ink, expand: true))
                .accessibilityIdentifier("wt-finish-dex")
            default:
                let done = page.quest.map { store.starterQuests.contains($0) } ?? true
                Button {
                    go(Page(rawValue: page.rawValue + 1) ?? .finale)
                } label: {
                    if done {
                        Label(page == .rules ? "Claim your reward" : "Next quest", systemImage: "arrow.right")
                            .labelStyle(TrailingIcon())
                    } else {
                        Label(lockedLabel, systemImage: "lock.fill")
                    }
                }
                .buttonStyle(ChunkyButtonStyle(fill: done ? Palette.orange : Palette.paperShade,
                                               text: done ? .white : Palette.muted, expand: true))
                .disabled(!done)
                .accessibilityIdentifier("wt-next")
            }
        }
        .frame(maxWidth: 420)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            let base = page == .finale ? Palette.night : Palette.water
            LinearGradient(stops: [.init(color: base.opacity(0), location: 0),
                                   .init(color: base, location: 0.35),
                                   .init(color: base, location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var lockedLabel: String {
        switch page {
        case .homeWater: return "Pick a water"
        case .starterCard: return "Flip the card"
        default: return "Answer to go on"
        }
    }

    // MARK: Actions

    private func go(_ next: Page) {
        withAnimation(still ? nil : .easeInOut(duration: 0.25)) { page = next }
        if next == .finale {
            confetti += 1
            store.seenWalkthrough = true
        }
    }

    private func earn(_ quest: StarterQuest) {
        guard store.complete(quest) else { return }
        withAnimation(still ? nil : .spring(response: 0.35, dampingFraction: 0.6)) { toast = quest.xp }
        let shown = quest.xp
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if toast == shown { withAnimation(still ? nil : .easeIn(duration: 0.25)) { toast = nil } }
        }
    }

    private func flip() {
        guard !flipped else { return }
        withAnimation(still ? nil : .spring(response: 0.7, dampingFraction: 0.75)) { flipped = true }
        confetti += 1
        earn(.starterCard)
    }

    private func nudge() {
        withAnimation(still ? nil : .linear(duration: 0.4)) { shake += 1 }
    }

    private func close() {
        store.seenWalkthrough = true
        withAnimation(still ? nil : .easeOut(duration: 0.2)) { model.walkthrough = false }
    }
}

// MARK: Pieces

private extension Text {
    func bodyText() -> some View {
        self.font(Fonts.body(16, .bold))
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Puts the icon after the words, for "Next quest →".
private struct TrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.title
            configuration.icon
        }
    }
}

/// "QUEST 2 OF 4", the reward, the quest's title and a line about it.
private struct QuestHeader: View {
    var number: Int
    var quest: StarterQuest
    var done: Bool
    var title: String
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Pill(text: "Quest \(number) of \(StarterQuest.allCases.count)", fill: Palette.paperShade)
                Pill(text: done ? "Earned +\(quest.xp) XP" : "+\(quest.xp) XP",
                     fill: done ? Palette.good : Palette.sun)
                    .accessibilityIdentifier("wt-reward")
                Spacer(minLength: 0)
            }
            Text(title)
                .font(Fonts.title(28, relativeTo: .title))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("wt-title")
            Text(text)
                .font(Fonts.body(16, .bold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker()
    }
}

/// One quest on the welcome list, with its XP or a check.
private struct QuestRow: View {
    var quest: StarterQuest
    var done: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "star.circle.fill")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(done ? Palette.good : Palette.orange)
            Text(quest.title)
                .font(Fonts.body(16, .extraBold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            Text(done ? "Done" : "+\(quest.xp) XP")
                .font(Fonts.body(14, .black))
                .foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A big tile for one water.
private struct WaterTile: View {
    var habitat: Habitat
    var count: Int
    var examples: [String]
    var picked: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(habitat.color)
                    Circle().strokeBorder(Palette.ink, lineWidth: 3)
                    Image(systemName: habitat.symbol)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                }
                .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text(habitat.rawValue)
                        .font(Fonts.title(24, relativeTo: .title3))
                        .foregroundStyle(Palette.ink)
                    Text("\(count) fish, like \(examples.joined(separator: ", ").lowercased())")
                        .font(Fonts.body(14, .bold))
                        .foregroundStyle(Palette.ink.opacity(0.8))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(picked ? Palette.ink : Palette.muted.opacity(0.6))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sticker(picked ? Palette.sun : Palette.paper, radius: 18, lift: picked ? 2 : 5)
            .offset(y: picked ? 3 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(habitat.rawValue), \(count) fish")
        .accessibilityAddTraits(picked ? .isSelected : [])
        .accessibilityIdentifier("wt-water-\(habitat.rawValue.lowercased())")
    }
}

/// One way to log, with its icon.
private struct HowRow: View {
    var symbol: String
    var title: String
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Palette.sun).overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2.5)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Fonts.title(20, relativeTo: .headline)).foregroundStyle(Palette.ink)
                Text(text).font(Fonts.body(15, .bold)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(radius: 16, lift: 4)
        .accessibilityElement(children: .combine)
    }
}

/// A quiz answer that turns green when right and red when wrong.
private struct ChoiceButton: View {
    enum Mark { case plain, right, wrong }
    var label: String
    var image: String?
    var symbol: String?
    var state: Mark
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let image {
                    Image(image)
                        .resizable()
                        .aspectRatio(600 / 780, contentMode: .fit)
                        .frame(width: 38)
                        .accessibilityHidden(true)
                } else if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .heavy))
                        .frame(width: 38)
                }
                Text(label)
                    .font(Fonts.body(17, .black))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                switch state {
                case .right: Image(systemName: "checkmark.circle.fill").font(.system(size: 24, weight: .heavy))
                case .wrong: Image(systemName: "xmark.circle.fill").font(.system(size: 24, weight: .heavy))
                case .plain: EmptyView()
                }
            }
            .foregroundStyle(state == .wrong ? Color.white : Palette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2.5))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(state == .right ? "Right" : state == .wrong ? "Wrong" : "")
    }

    private var fill: Color {
        switch state {
        case .plain: return .white
        case .right: return Palette.good
        case .wrong: return Color(hex: 0xE5484D)
        }
    }
}

/// A side to side wobble for a wrong answer.
private struct Shake: GeometryEffect {
    var amount: CGFloat
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(shakes * .pi * 4), y: 0))
    }
}

/// A row on the finale: a patch, a title and a line.
private struct FinaleRow: View {
    var patch: PatchView
    var title: String
    var titleColor: Color
    var text: String

    var body: some View {
        HStack(spacing: 12) {
            patch.accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Fonts.title(22)).foregroundStyle(titleColor)
                Text(text).font(Fonts.body(15, .extraBold)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The current event (or the next one), as a little banner.
private struct EventTeaser: View {
    var body: some View {
        let now = AppClock.now
        let active = Seasons.active(on: now).first
        let next = Seasons.upcoming(after: now).first
        if let event = active ?? next?.event {
            HStack(spacing: 12) {
                Image(systemName: event.symbol)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color(hex: event.colorHex)).overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2.5)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(active != nil ? "ON NOW" : "COMING UP")
                        .font(Fonts.body(12, .black, relativeTo: .caption))
                        .foregroundStyle(Palette.muted)
                    Text(event.name)
                        .font(Fonts.title(21, relativeTo: .headline))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(event.range.text). +\(event.rewardXP) XP and a limited card.")
                        .font(Fonts.body(14, .bold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sticker(radius: 16, lift: 4)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("wt-event")
        }
    }
}

/// Two shadow cards fanned out behind the card back.
private struct CardFan: View {
    var body: some View {
        ZStack {
            Image("sil-mahi").resizable().aspectRatio(600 / 780, contentMode: .fit)
                .frame(width: 108)
                .rotationEffect(.degrees(-14))
                .offset(x: -78, y: 12)
            Image("sil-bass").resizable().aspectRatio(600 / 780, contentMode: .fit)
                .frame(width: 108)
                .rotationEffect(.degrees(14))
                .offset(x: 78, y: 12)
            CardBack()
                .frame(width: 132, height: 172)
                .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 5)
        }
        .frame(height: 196)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

/// The starter card's face: not a fish, so it gives no species away.
struct StarterCardFace: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Palette.sun)
            .overlay {
                Sunburst(color: .white.opacity(0.45))
                    .background(Palette.waterLight)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.ink, lineWidth: 3))
                    .padding(.horizontal, 12)
                    .padding(.top, 40)
                    .padding(.bottom, 38)
            }
            .overlay {
                PatchView(shape: .star, symbol: "fish.fill", earned: true, color: Palette.orange, size: 96)
                    .offset(y: 1)
            }
            .overlay(alignment: .top) {
                Text("ROOKIE")
                    .font(Fonts.title(24))
                    .kerning(1.5)
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 9)
            }
            .overlay(alignment: .bottom) {
                Text("STARTER CARD · #000")
                    .font(Fonts.body(12, .black))
                    .foregroundStyle(Palette.ink)
                    .padding(.bottom, 12)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Palette.ink, lineWidth: 5)
            }
            .dynamicTypeSize(.large)
    }
}
