import Foundation

/// The moon's eight phases.
public enum MoonPhase: String, Codable, CaseIterable, Sendable {
    case new, waxingCrescent, firstQuarter, waxingGibbous, full, waningGibbous, lastQuarter, waningCrescent

    public var label: String {
        switch self {
        case .new: return "New moon"
        case .waxingCrescent: return "Waxing crescent"
        case .firstQuarter: return "First quarter"
        case .waxingGibbous: return "Waxing gibbous"
        case .full: return "Full moon"
        case .waningGibbous: return "Waning gibbous"
        case .lastQuarter: return "Last quarter"
        case .waningCrescent: return "Waning crescent"
        }
    }

    /// The SF Symbol for this phase.
    public var symbol: String {
        switch self {
        case .new: return "moonphase.new.moon"
        case .waxingCrescent: return "moonphase.waxing.crescent"
        case .firstQuarter: return "moonphase.first.quarter"
        case .waxingGibbous: return "moonphase.waxing.gibbous"
        case .full: return "moonphase.full.moon"
        case .waningGibbous: return "moonphase.waning.gibbous"
        case .lastQuarter: return "moonphase.last.quarter"
        case .waningCrescent: return "moonphase.waning.crescent"
        }
    }

    /// Four wider groups, so a handful of catches can still show a pattern.
    public var group: MoonGroup {
        switch self {
        case .waningCrescent, .new: return .new
        case .waxingCrescent, .firstQuarter: return .waxing
        case .waxingGibbous, .full: return .full
        case .waningGibbous, .lastQuarter: return .waning
        }
    }
}

/// The moon's phases in four groups, for best bite times.
public enum MoonGroup: String, Codable, CaseIterable, Sendable {
    case new, waxing, full, waning

    public var label: String {
        switch self {
        case .new: return "Around the new moon"
        case .waxing: return "Moon growing"
        case .full: return "Around the full moon"
        case .waning: return "Moon shrinking"
        }
    }

    public var symbol: String {
        switch self {
        case .new: return "moonphase.new.moon"
        case .waxing: return "moonphase.first.quarter"
        case .full: return "moonphase.full.moon"
        case .waning: return "moonphase.last.quarter"
        }
    }
}

/// The part of the day by the sun at the spot, so it means the same in
/// December as in June.
public enum TimeOfDay: String, Codable, CaseIterable, Sendable {
    case dawn, morning, midday, afternoon, dusk, night

    public var label: String {
        switch self {
        case .dawn: return "Dawn"
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .afternoon: return "Afternoon"
        case .dusk: return "Dusk"
        case .night: return "Night"
        }
    }

    public var symbol: String {
        switch self {
        case .dawn: return "sunrise.fill"
        case .morning: return "sun.max.fill"
        case .midday: return "sun.max.fill"
        case .afternoon: return "sun.haze.fill"
        case .dusk: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }
}

/// The moon and sun worked out on the phone, with no internet. Low-precision
/// formulas from Jean Meeus, "Astronomical Algorithms": good to well under an
/// hour for the moon's phase and a couple of minutes for sunrise and sunset.
public enum Sky {
    public static let southFlorida = (latitude: 25.9, longitude: -80.4)

    private static let rad = Double.pi / 180

    /// Julian centuries since noon UTC on January 1, 2000.
    private static func centuries(_ date: Date) -> Double {
        (date.timeIntervalSince1970 / 86400 + 2440587.5 - 2451545.0) / 36525
    }

    private static func norm(_ degrees: Double) -> Double {
        let d = degrees.truncatingRemainder(dividingBy: 360)
        return d < 0 ? d + 360 : d
    }

    /// The sun's apparent longitude, in degrees.
    private static func sunLongitude(_ t: Double) -> Double {
        let l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
        let m = (357.52911 + 35999.05029 * t - 0.0001537 * t * t) * rad
        let c = (1.914602 - 0.004817 * t) * sin(m) + (0.019993 - 0.000101 * t) * sin(2 * m) + 0.000289 * sin(3 * m)
        return norm(l0 + c)
    }

    /// The moon's longitude, in degrees, from its biggest terms.
    private static func moonLongitude(_ t: Double) -> Double {
        let lp = 218.3164477 + 481267.88123421 * t
        let d = (297.8501921 + 445267.1114034 * t) * rad
        let m = (357.5291092 + 35999.0502909 * t) * rad
        let mp = (134.9633964 + 477198.8675055 * t) * rad
        let f = (93.2720950 + 483202.0175233 * t) * rad
        let terms: Double =
            6.288774 * sin(mp)
            + 1.274027 * sin(2 * d - mp)
            + 0.658314 * sin(2 * d)
            + 0.213618 * sin(2 * mp)
            - 0.185116 * sin(m)
            - 0.114332 * sin(2 * f)
            + 0.058793 * sin(2 * d - 2 * mp)
            + 0.057066 * sin(2 * d - m - mp)
            + 0.053322 * sin(2 * d + mp)
            + 0.045758 * sin(2 * d - m)
            - 0.040923 * sin(m - mp)
            - 0.034720 * sin(d)
            - 0.030383 * sin(m + mp)
            + 0.015327 * sin(2 * d - 2 * f)
            - 0.012528 * sin(mp + 2 * f)
            + 0.010980 * sin(mp - 2 * f)
            + 0.010675 * sin(4 * d - mp)
            + 0.010034 * sin(3 * mp)
            + 0.008548 * sin(4 * d - 2 * mp)
        return norm(lp + terms)
    }

    /// How far the moon is ahead of the sun, 0 to 360 degrees (0 is new, 180 is full).
    public static func moonElongation(at date: Date) -> Double {
        let t = centuries(date)
        return norm(moonLongitude(t) - sunLongitude(t))
    }

    public static func moon(at date: Date) -> (phase: MoonPhase, lit: Double) {
        let e = moonElongation(at: date)
        let index = Int(((e + 22.5) / 45).rounded(.down)) % 8
        let lit = (1 - cos(e * rad)) / 2
        return (MoonPhase.allCases[index], (lit * 100).rounded() / 100)
    }

    /// Sunrise, solar noon and sunset for the day that holds `date` at that spot.
    /// Nil sunrise and sunset never happen this far south, but are handled.
    public static func sun(on date: Date, latitude: Double, longitude: Double)
        -> (rise: Date?, noon: Date, set: Date?) {
        // The local solar day that holds `date`.
        let dayStart = (date.timeIntervalSince1970 + longitude / 360 * 86400) / 86400
        let localDay = dayStart.rounded(.down)
        // Solar noon guess in UTC for that day.
        var noonUTC = (localDay + 0.5) * 86400 - longitude / 360 * 86400
        var decl = 0.0
        for _ in 0..<2 {
            let t = centuries(Date(timeIntervalSince1970: noonUTC))
            let (declination, eqTime) = solar(t)
            decl = declination
            noonUTC = (localDay + 0.5) * 86400 - longitude / 360 * 86400 - eqTime * 60
        }
        let noon = Date(timeIntervalSince1970: noonUTC)
        let cosH = (cos(90.833 * rad) - sin(latitude * rad) * sin(decl * rad)) / (cos(latitude * rad) * cos(decl * rad))
        guard cosH > -1, cosH < 1 else { return (nil, noon, nil) }
        let halfDay = acos(cosH) / rad / 15 * 3600
        return (noon.addingTimeInterval(-halfDay), noon, noon.addingTimeInterval(halfDay))
    }

    /// The sun's declination (degrees) and the equation of time (minutes).
    private static func solar(_ t: Double) -> (Double, Double) {
        let l0 = norm(280.46646 + t * (36000.76983 + 0.0003032 * t))
        let m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let c = sin(m * rad) * (1.914602 - t * (0.004817 + 0.000014 * t)) + sin(2 * m * rad) * (0.019993 - 0.000101 * t)
            + sin(3 * m * rad) * 0.000289
        let omega = 125.04 - 1934.136 * t
        let lambda = l0 + c - 0.00569 - 0.00478 * sin(omega * rad)
        let eps0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let eps = eps0 + 0.00256 * cos(omega * rad)
        let decl = asin(sin(eps * rad) * sin(lambda * rad)) / rad
        let y = tan(eps * rad / 2) * tan(eps * rad / 2)
        let eq = y * sin(2 * l0 * rad) - 2 * e * sin(m * rad) + 4 * e * y * sin(m * rad) * cos(2 * l0 * rad)
            - 0.5 * y * y * sin(4 * l0 * rad) - 1.25 * e * e * sin(2 * m * rad)
        return (decl, 4 * eq / rad)
    }

    /// Dawn and dusk run an hour either side of sunrise and sunset. Midday is
    /// solar noon, give or take an hour and a half.
    public static func timeOfDay(at date: Date, latitude: Double, longitude: Double) -> TimeOfDay {
        let sun = sun(on: date, latitude: latitude, longitude: longitude)
        guard let rise = sun.rise, let set = sun.set else { return .midday }
        let hour: TimeInterval = 3600
        if date < rise.addingTimeInterval(-hour) || date >= set.addingTimeInterval(hour) { return .night }
        if date < rise.addingTimeInterval(hour) { return .dawn }
        if date >= set.addingTimeInterval(-hour) { return .dusk }
        if date < sun.noon.addingTimeInterval(-1.5 * hour) { return .morning }
        if date < sun.noon.addingTimeInterval(1.5 * hour) { return .midday }
        return .afternoon
    }
}
