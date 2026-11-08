import SwiftUI
import Observation

enum AppTab: String, CaseIterable, Identifiable {
    case dex, events, logbook, profile
    var id: String { rawValue }

    var title: String {
        switch self {
        case .dex: return "Dex"
        case .events: return "Events"
        case .logbook: return "Logbook"
        case .profile: return "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .dex: return "square.grid.3x3.fill"
        case .events: return "calendar"
        case .logbook: return "book.closed.fill"
        case .profile: return "person.crop.circle.fill"
        }
    }
}

/// Where the person is in the app: the tab, the log sheet, the fish open on
/// the open Duo's right half, and the unlock moment after a save.
@MainActor
@Observable
final class AppModel {
    var tab: AppTab = .dex
    var logging = false
    /// A fish already picked when Log opens from its page.
    var logPreset: String?
    /// The card shown on the open Duo's right half.
    var selected: DexCard?
    /// Pages pushed on phones and the folded Duo.
    var dexPath: [DexCard] = []
    /// Fish pages pushed from the Events tab.
    var eventsPath: [DexCard] = []
    var unlock: SaveResult?
    /// The starter tour, shown over everything.
    var walkthrough = false

    func startLog(preset: String? = nil) {
        logPreset = preset
        logging = true
    }

    func finishLog(_ result: SaveResult?) {
        logging = false
        logPreset = nil
        if let result {
            unlock = result
            selected = result.award.unlocksTrophyBass ? .trophyBass : .species(result.species)
        }
    }

    func applyLaunchOptions(catalog: SpeciesCatalog) {
        let options = LaunchOptions.current
        if let tab = options.tab.flatMap(AppTab.init(rawValue:)) { self.tab = tab }
        if let id = options.openSpecies {
            let card: DexCard? = id == SpeciesCatalog.trophyBassID ? .trophyBass : catalog[id].map(DexCard.species)
            if let card {
                selected = card
                dexPath = [card]
            }
        } else if selected == nil, let first = catalog.species.first {
            selected = .species(first)
        }
        if let id = options.logSpecies, catalog[id] != nil { startLog(preset: id) }
        if options.scanSample { startLog() }
    }
}
