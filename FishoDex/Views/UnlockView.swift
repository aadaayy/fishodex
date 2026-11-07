import SwiftUI

/// The moment after saving a catch. A new fish flips its card over from the
/// card back, with a rarity sunburst and confetti; then the XP pops, the bar
/// fills, and any level up or new patch shows. A repeat catch gets a short
/// version with the XP.
struct UnlockView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var result: SaveResult
    var onClose: () -> Void

    @State private var flipped = false
    @State private var showXP = false
    @State private var barXP: Int
    @State private var confetti = false
    @State private var spin = false

    init(result: SaveResult, onClose: @escaping () -> Void) {
        self.result = result
        self.onClose = onClose
        _barXP = State(initialValue: result.xpAfter - result.award.xp)
    }

    private var still: Bool { reduceMotion || LaunchOptions.current.still }
    private var isUnlock: Bool { result.award.isNewSpecies || result.award.unlocksTrophyBass }
    private var rarity: Rarity { result.award.unlocksTrophyBass ? .trophy : result.species.rarity }
    private var cardImage: String {
        result.award.unlocksTrophyBass ? "card-\(SpeciesCatalog.trophyBassID)" : "card-\(result.species.id)"
    }
    private var leveledUp: Bool { result.levelAfter > result.levelBefore }

    private var headline: String {
        if result.award.unlocksTrophyBass { return "Trophy bass!" }
        if result.award.isNewSpecies { return "New species!" }
        if !result.award.completedEvents.isEmpty { return "Event finished!" }
        if result.award.isPersonalBest { return "New personal best!" }
        return "Catch logged"
    }

    var body: some View {
        ZStack {
            WaterBackground(deep: true)
                .onTapGesture {}
            if confetti && !still { ConfettiView().allowsHitTesting(false) }

            ScrollView {
                VStack(spacing: 14) {
                    Text(headline)
                        .font(Fonts.title(36, relativeTo: .largeTitle))
                        .foregroundStyle(Palette.sun)
                        .shadow(color: Palette.ink, radius: 0, x: 0, y: 3)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("unlock-title")
                    Text(result.species.name)
                        .font(Fonts.title(24))
                        .foregroundStyle(.white)

                    card
                    xpPanel
                    ForEach(result.award.completedEvents, id: \.self) { id in
                        if let event = Seasons.event(id) { EventEarnedPanel(event: event) }
                    }
                    if !result.newBadges.isEmpty { patches }

                    Button("Continue", action: onClose)
                        .buttonStyle(ChunkyButtonStyle(expand: true))
                        .frame(maxWidth: 360)
                        .accessibilityIdentifier("unlock-continue")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear(perform: play)
        .accessibilityAddTraits(.isModal)
    }

    // MARK: Parts

    private var card: some View {
        let width: CGFloat = isUnlock ? 240 : 170
        return ZStack {
            CardBack()
                .opacity(flipped ? 0 : 1)
            Image(cardImage)
                .resizable()
                .aspectRatio(600 / 780, contentMode: .fit)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipped ? 1 : 0)
        }
        .frame(width: width, height: width * 780 / 600)
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(result.species.name) card, \(rarity.rawValue)")
        .accessibilityIdentifier("unlock-card")
        .frame(maxWidth: .infinity)
        .frame(height: isUnlock ? 340 : 240)
        .background {
            // Behind the card, so it never widens the screen.
            Sunburst(color: rarity.color.opacity(isUnlock ? 0.7 : 0.35))
                .frame(width: 440, height: 440)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .opacity(flipped ? 1 : 0)
                .accessibilityHidden(true)
        }
        .clipped()
    }

    private var xpPanel: some View {
        let level = Leveling.level(for: barXP)
        return VStack(spacing: 10) {
            Text("+\(result.award.xp) XP")
                .font(Fonts.title(40))
                .foregroundStyle(Palette.ink)
                .scaleEffect(showXP ? 1 : 0.4)
                .opacity(showXP ? 1 : 0)
                .accessibilityIdentifier("unlock-xp")
            VStack(spacing: 4) {
                ForEach(Array(result.award.reasons.enumerated()), id: \.offset) { _, reason in
                    HStack {
                        Text(reason.label).font(Fonts.body(15, .extraBold))
                        Spacer()
                        Text("+\(reason.xp)").font(Fonts.body(15, .black))
                    }
                    .foregroundStyle(Palette.ink)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Level \(level)").font(Fonts.body(14, .black))
                    Spacer()
                    Text(Leveling.title(for: level)).font(Fonts.body(14, .black))
                }
                .foregroundStyle(Palette.ink)
                XPBar(fraction: Leveling.fraction(for: barXP), height: 18)
            }
            if leveledUp {
                HStack(spacing: 10) {
                    PatchView(shape: .shield, text: "\(result.levelAfter)", earned: true, color: Palette.sun, size: 54)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Level up!").font(Fonts.title(24)).foregroundStyle(Palette.orange)
                        Text("You're level \(result.levelAfter), \(Leveling.title(for: result.levelAfter)).")
                            .font(Fonts.body(15, .extraBold))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .opacity(showXP ? 1 : 0)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("unlock-level-up")
            }
        }
        .padding(16)
        .sticker()
    }

    private var patches: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelTitle(text: result.newBadges.count == 1 ? "New patch" : "New patches", symbol: "star.fill")
            ForEach(result.newBadges) { badge in
                HStack(spacing: 12) {
                    PatchView(shape: badge.shape, symbol: badge.symbol, earned: true, color: Palette.orange, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(badge.name).font(Fonts.title(20)).foregroundStyle(Palette.ink)
                        Text(badge.detail).font(Fonts.body(14, .bold)).foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker()
        .opacity(showXP ? 1 : 0)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unlock-patches")
    }

    // MARK: Timing

    private func play() {
        guard !still else {
            flipped = true
            showXP = true
            barXP = result.xpAfter
            return
        }
        withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) { spin = true }
        let flipDelay = isUnlock ? 0.35 : 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + flipDelay) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { flipped = true }
            if isUnlock { confetti = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + flipDelay + 0.6) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { showXP = true }
            withAnimation(.easeOut(duration: 0.9).delay(0.2)) { barXP = result.xpAfter }
        }
    }
}

/// The navy card back: a fish badge on waves.
struct CardBack: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Palette.night)
            .overlay {
                WaterBackground(deep: true)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(10)
            }
            .overlay {
                ZStack {
                    Circle().fill(Palette.sun)
                    Circle().strokeBorder(Palette.ink, lineWidth: 4)
                    Image(systemName: "fish.fill")
                        .font(.system(size: 46, weight: .black))
                        .foregroundStyle(Palette.ink)
                }
                .frame(width: 104, height: 104)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Palette.ink, lineWidth: 5)
            }
            .overlay(alignment: .bottom) {
                Text("FISHODEX")
                    .font(Fonts.title(20))
                    .kerning(2)
                    .foregroundStyle(Palette.sun)
                    .padding(.bottom, 22)
            }
    }
}

/// Bits of colored paper falling from the top.
struct ConfettiView: View {
    @State private var start = Date()
    private let pieces: [Piece] = (0..<70).map { _ in Piece() }

    struct Piece {
        let x = Double.random(in: 0...1)
        let delay = Double.random(in: 0...0.6)
        let speed = Double.random(in: 0.35...0.7)
        let spin = Double.random(in: 2...7)
        let size = CGFloat.random(in: 7...13)
        let color = [Palette.sun, Palette.orange, Palette.waterLight, Palette.good, Color.white].randomElement()!
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                for p in pieces {
                    let age = t - p.delay
                    guard age > 0 else { continue }
                    let y = -20 + age * p.speed * size.height
                    guard y < size.height + 20 else { continue }
                    let x = p.x * size.width + sin(age * 3 + p.x * 10) * 18
                    var piece = context
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(age * p.spin))
                    piece.fill(Path(CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)),
                               with: .color(p.color))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// After a catch finishes an event: its limited card.
struct EventEarnedPanel: View {
    var event: SeasonEvent

    var body: some View {
        HStack(spacing: 14) {
            Image(event.cardImage)
                .resizable()
                .aspectRatio(600 / 780, contentMode: .fit)
                .frame(width: 96)
                .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("EVENT CARD EARNED")
                    .font(Fonts.body(12, .black, relativeTo: .caption))
                    .foregroundStyle(Palette.muted)
                Text(event.name)
                    .font(Fonts.title(24))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("+\(event.rewardXP) XP. It's in your Events tab.")
                    .font(Fonts.body(14, .extraBold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: 420)
        .sticker(Palette.paper)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("event-earned-\(event.id)")
    }
}
