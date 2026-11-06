import Foundation

/// Inches and pounds by default; metric if the person picks it.
public enum UnitSystem: String, Codable, CaseIterable, Sendable {
    case us, metric

    public var lengthUnit: String { self == .us ? "in" : "cm" }
    public var weightUnit: String { self == .us ? "lb" : "kg" }

    public func length(_ inches: Double) -> String {
        self == .us ? "\(Self.trim(inches)) in" : "\(Self.trim(inches * 2.54)) cm"
    }

    public func weight(_ pounds: Double) -> String {
        self == .us ? "\(Self.trim(pounds)) lb" : "\(Self.trim(pounds * 0.45359237)) kg"
    }

    /// Turns what someone typed into inches (or pounds), in this unit system.
    public func inches(fromTyped value: Double) -> Double { self == .us ? value : value / 2.54 }
    public func pounds(fromTyped value: Double) -> Double { self == .us ? value : value / 0.45359237 }
    public func typedLength(_ inches: Double) -> Double { self == .us ? inches : inches * 2.54 }
    public func typedWeight(_ pounds: Double) -> Double { self == .us ? pounds : pounds * 0.45359237 }

    /// "8.5", "12", "0.75": at most two decimals, no trailing zeros.
    public static func trim(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        var text = String(format: "%.2f", rounded)
        while text.hasSuffix("0") { text.removeLast() }
        return text
    }

    /// Reads "8.5" or "8,5" as a number; nil when empty or not a number.
    public static func parse(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned), value > 0, value.isFinite else { return nil }
        return value
    }
}
