import SwiftUI

/// Photo ID: looks at the photo on the phone and shows the three fish it
/// looks most like, with how sure it is. Nothing is saved or unlocked here:
/// the person taps the right fish (or picks one by name), then fills in the
/// details and saves, the same as any catch.
struct PhotoIDView: View {
    @Environment(CatchStore.self) private var store
    var photo: UIImage
    var onChoose: (_ speciesID: String, _ guesses: [String]) -> Void
    var onPickByName: (_ guesses: [String]) -> Void
    var onClose: () -> Void

    enum Stage: Equatable {
        case looking
        case done(ScanResult)
        case unavailable
    }

    @State private var stage: Stage = .looking

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                FlowHeader(title: "Photo ID", onClose: onClose)
                photoCard
                switch stage {
                case .looking:
                    looking
                case .done(let result):
                    headline(result)
                    VStack(spacing: 8) {
                        ForEach(Array(result.guesses.enumerated()), id: \.element.id) { index, guess in
                            guessRow(guess, best: index == 0 && result.verdict == .sure)
                        }
                    }
                    pickByName(result.suggestionIDs)
                case .unavailable:
                    unavailable
                }
                Label("Photo ID works on this phone, even offline. Your photo never leaves it.", systemImage: "lock.fill")
                    .font(Fonts.body(13, .extraBold))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(WaterBackground())
        .toolbar(.hidden, for: .navigationBar)
        .task { await identify() }
    }

    private func identify() async {
        guard stage == .looking else { return }
        do {
            let labels = try await FishIdentifier.shared.labels(for: photo)
            let result = ScanResult.make(from: labels, catalog: store.catalog)
            stage = result.guesses.isEmpty ? .unavailable : .done(result)
        } catch {
            stage = .unavailable
        }
    }

    private var photoCard: some View {
        Image(uiImage: photo)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.ink, lineWidth: 3))
            .overlay(alignment: .topLeading) {
                Pill(text: "Your photo", fill: Palette.paper)
                    .padding(10)
            }
            .accessibilityLabel("Your photo")
            .accessibilityIdentifier("scan-photo")
    }

    private var looking: some View {
        HStack(spacing: 12) {
            ProgressView().tint(Palette.ink).controlSize(.large)
            Text("Looking at your fish…").font(Fonts.title(22)).foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
        }
        .padding(16)
        .sticker()
        .accessibilityIdentifier("scan-looking")
    }

    private func headline(_ result: ScanResult) -> some View {
        let name = result.guesses.first.flatMap { store.catalog[$0.speciesID]?.name } ?? "a fish"
        let title: String
        let detail: String
        let fill: Color
        switch result.verdict {
        case .sure:
            title = "Looks like \(Self.article(for: name)) \(name)"
            detail = "Check it's right, then tap it to fill in your catch."
            fill = Palette.sun
        case .unsure:
            title = "Could be one of these"
            detail = "These look close. Check the fins and markings, then tap the right one."
            fill = Palette.paper
        case .notInDex:
            title = "Maybe not a dex fish"
            detail = "FishoDex has 63 South Florida fish so far. If it's one of these, tap it. If not, pick it by name."
            fill = Palette.paper
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Fonts.title(24, relativeTo: .title))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("scan-headline")
            Text(detail)
                .font(Fonts.body(15, .bold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(fill)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("scan-verdict-\(result.verdict.rawValue)")
    }

    private func guessRow(_ guess: ScanGuess, best: Bool) -> some View {
        let species = store.catalog[guess.speciesID]
        let caught = store.progress.caught.contains(guess.speciesID)
        return Button {
            onChoose(guess.speciesID, stageGuesses)
        } label: {
            HStack(spacing: 12) {
                FishThumb(id: guess.speciesID, size: 62)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(species?.name ?? guess.speciesID)
                            .font(Fonts.title(19))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                        Text(guess.percentText)
                            .font(Fonts.title(19))
                            .foregroundStyle(Palette.ink)
                            .monospacedDigit()
                    }
                    ConfidenceBar(value: guess.confidence, fill: best ? Palette.orange : Palette.water)
                    HStack(spacing: 6) {
                        Text("\(species?.numberText ?? "") · \(species?.habitat.rawValue ?? "")")
                            .font(Fonts.body(12, .bold))
                            .foregroundStyle(Palette.muted)
                        Spacer(minLength: 0)
                        if caught {
                            Label("In dex", systemImage: "checkmark.circle.fill")
                                .font(Fonts.body(12, .black)).foregroundStyle(Palette.good)
                        } else if let s = species {
                            Pill(text: "New +\(s.rarity.newSpeciesXP)", fill: Palette.sun, size: 10)
                        }
                    }
                }
                Image(systemName: "chevron.right").font(.system(size: 16, weight: .black)).foregroundStyle(Palette.ink)
            }
            .padding(10)
            .sticker(best ? Color(hex: 0xFFEDB8) : Palette.paper, radius: 16, lift: 4)
        }
        .buttonStyle(CardPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(species?.name ?? guess.speciesID), \(guess.percentText) sure")
        .accessibilityIdentifier("scan-guess-\(guess.speciesID)")
    }

    static func article(for name: String) -> String {
        "AEIOU".contains(name.prefix(1).uppercased()) ? "an" : "a"
    }

    private var stageGuesses: [String] {
        if case .done(let result) = stage { return result.suggestionIDs }
        return []
    }

    private func pickByName(_ guesses: [String]) -> some View {
        Button { onPickByName(guesses) } label: {
            Label("None of these? Pick by name", systemImage: "magnifyingglass")
        }
        .buttonStyle(ChunkyButtonStyle(fill: Palette.paper, text: Palette.ink, size: 17, expand: true))
        .accessibilityIdentifier("scan-pick-by-name")
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Couldn't name this one").font(Fonts.title(22)).foregroundStyle(Palette.ink)
            BodyText("Photo ID couldn't read this photo. Pick the fish by name, and the photo stays with your catch.")
            Button { onPickByName([]) } label: {
                Label("Pick by name", systemImage: "magnifyingglass")
            }
            .buttonStyle(ChunkyButtonStyle(size: 18, expand: true))
            .accessibilityIdentifier("scan-pick-by-name")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker()
        .accessibilityIdentifier("scan-unavailable")
    }
}

/// How sure photo ID is, as a short filled bar.
struct ConfidenceBar: View {
    var value: Double
    var fill: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.paperShade)
                Capsule().fill(fill)
                    .frame(width: max(10, geometry.size.width * min(1, max(0, value))))
            }
            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2))
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }
}
