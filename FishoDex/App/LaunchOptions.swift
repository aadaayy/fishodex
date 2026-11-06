import CoreGraphics
import Foundation

/// Settings the automatic checks pass when they launch the app, so the
/// screenshots show the same data every time. Normal launches use none.
struct LaunchOptions {
    /// Keep catches in memory only, starting empty (or with sample catches).
    var testing = false
    /// Fill the dex with a set of sample catches.
    var demo = false
    /// Draw the screen at another phone's size (in points), shrunk to fit,
    /// e.g. "-previewSize 951x669" for the open iPhone Duo.
    var previewSize: CGSize?
    /// Open the app on a tab: dex, logbook or profile.
    var tab: String?
    /// Open a fish's page straight away.
    var openSpecies: String?
    /// Turn off animations (for steady screenshots).
    var still = false
    /// Open Log a catch with this fish already picked.
    var logSpecies: String?
    /// Save a catch of this fish straight away and show the unlock moment.
    var showUnlock: String?
    /// The weight in pounds for that catch, e.g. 10.6 for a trophy bass.
    var unlockPounds: Double?

    static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    init(arguments: [String] = []) {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        testing = arguments.contains("-uiTesting")
        demo = arguments.contains("-demo")
        still = arguments.contains("-still")
        tab = value(after: "-tab")
        openSpecies = value(after: "-openSpecies")
        logSpecies = value(after: "-logSpecies")
        showUnlock = value(after: "-showUnlock")
        unlockPounds = value(after: "-unlockPounds").flatMap(Double.init)
        if arguments.contains("-openDuoPreview") {
            previewSize = CGSize(width: 951, height: 669)
        } else if let text = value(after: "-previewSize") {
            let parts = text.split(separator: "x").compactMap { Double($0) }
            if parts.count == 2 { previewSize = CGSize(width: parts[0], height: parts[1]) }
        }
    }
}
