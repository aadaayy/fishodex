import Foundation

/// One guess from photo ID: a dex fish and how sure the model is (0 to 1).
public struct ScanGuess: Codable, Hashable, Sendable, Identifiable {
    public var speciesID: String
    public var confidence: Double
    public var id: String { speciesID }

    public init(speciesID: String, confidence: Double) {
        self.speciesID = speciesID
        self.confidence = confidence
    }

    /// "87%", never "0%" or "100%" so it never reads as certain or impossible.
    public var percentText: String {
        let value = min(99, max(1, Int((confidence * 100).rounded())))
        return "\(value)%"
    }
}

/// What photo ID makes of a photo, ready to show. Nothing unlocks from this
/// alone: the person always confirms the fish (or picks another by name)
/// before the catch is saved.
public struct ScanResult: Hashable, Sendable {
    public enum Verdict: String, Sendable {
        /// The first guess is likely right.
        case sure
        /// Several fish are close; the person should check.
        case unsure
        /// It looks most like a fish that isn't in the dex.
        case notInDex
    }

    /// The model's label for "a fish that isn't in the dex".
    public static let otherLabel = "other"
    /// How many guesses to show.
    public static let shown = 3
    /// The first guess counts as sure at or above this. Set from the test
    /// report: at this level the first guess was right far more often than not.
    public static let sureLevel = 0.6

    public var guesses: [ScanGuess]
    public var verdict: Verdict
    /// How sure the model was that this is a fish outside the dex.
    public var otherConfidence: Double

    public init(guesses: [ScanGuess], verdict: Verdict, otherConfidence: Double) {
        self.guesses = guesses
        self.verdict = verdict
        self.otherConfidence = otherConfidence
    }

    /// Turns the model's raw labels into guesses: drops labels the dex doesn't
    /// know, keeps the top three dex fish, and decides how sure to sound.
    public static func make(from labels: [(label: String, confidence: Double)], catalog: SpeciesCatalog) -> ScanResult {
        let sorted = labels.sorted { $0.confidence > $1.confidence }
        let other = sorted.first { $0.label == otherLabel }?.confidence ?? 0
        var seen = Set<String>()
        var guesses: [ScanGuess] = []
        for item in sorted where item.label != otherLabel && catalog[item.label] != nil && !seen.contains(item.label) {
            seen.insert(item.label)
            guesses.append(ScanGuess(speciesID: item.label, confidence: item.confidence))
            if guesses.count == shown { break }
        }
        let top = guesses.first?.confidence ?? 0
        let verdict: Verdict
        if guesses.isEmpty || (other > top && other >= 0.5) {
            verdict = .notInDex
        } else if top >= sureLevel {
            verdict = .sure
        } else {
            verdict = .unsure
        }
        return ScanResult(guesses: guesses, verdict: verdict, otherConfidence: other)
    }

    /// The ids saved with the catch, so it remembers what the scan said.
    public var suggestionIDs: [String] { guesses.map(\.speciesID) }
}
