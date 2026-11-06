import Foundation
import Observation
import UIKit
import Photos

/// What saving a catch did: XP, any card unlocks, level ups and new patches.
struct SaveResult: Identifiable {
    let id = UUID()
    var savedCatch: Catch
    var species: Species
    var award: CatchAward
    var levelBefore: Int
    var levelAfter: Int
    var xpAfter: Int
    var newBadges: [Badge]
}

/// The person's catches, saved on the phone. Photos live in the app's own
/// Photos folder and never leave the phone.
@MainActor
@Observable
final class CatchStore {
    let catalog: SpeciesCatalog
    private(set) var catches: [Catch] = []
    private(set) var progress = DexProgress()
    private(set) var badges: [Badge] = []

    var units: UnitSystem {
        didSet { defaults.set(units.rawValue, forKey: "units") }
    }
    var saveToPhotos: Bool {
        didSet { defaults.set(saveToPhotos, forKey: "saveToPhotos") }
    }

    private let folder: URL
    private let persists: Bool
    private let defaults: UserDefaults

    init(catalog: SpeciesCatalog, folder: URL? = nil, persists: Bool = true, defaults: UserDefaults = .standard) {
        self.catalog = catalog
        self.persists = persists
        self.defaults = defaults
        self.folder = folder ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        units = UnitSystem(rawValue: defaults.string(forKey: "units") ?? "") ?? .us
        saveToPhotos = defaults.bool(forKey: "saveToPhotos")
        if persists { load() }
        refresh()
    }

    static func makeCatalog() -> SpeciesCatalog {
        guard let url = Bundle.main.url(forResource: "species", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? SpeciesCatalog(data: data) else {
            assertionFailure("species.json is missing or broken")
            return SpeciesCatalog(species: [])
        }
        return catalog
    }

    // MARK: Reading

    var newestFirst: [Catch] {
        catches.sorted { ($0.date, $0.createdAt) > ($1.date, $1.createdAt) }
    }

    func catches(of speciesID: String) -> [Catch] {
        newestFirst.filter { $0.speciesID == speciesID }
    }

    var trophyBassCatches: [Catch] { newestFirst.filter(\.isTrophyBass) }

    func preview(_ draft: Catch) -> CatchAward? {
        ProgressEngine.preview(draft, existing: catches, catalog: catalog)
    }

    /// "8.5 lb · 30 in", or nil if neither was logged.
    func sizeText(_ c: Catch) -> String? {
        let parts = [c.weightPounds.map(units.weight), c.lengthInches.map(units.length)].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func biggestText(for speciesID: String) -> String? {
        if let w = progress.bestWeight[speciesID] { return units.weight(w) }
        if let l = progress.bestLength[speciesID] { return units.length(l) }
        return nil
    }

    // MARK: Changing

    @discardableResult
    func add(_ draft: Catch, photo: UIImage?) -> SaveResult? {
        guard let species = catalog[draft.speciesID] else { return nil }
        var c = draft
        if let photo, let data = photo.jpegData(compressionQuality: 0.82) {
            let name = "\(c.id.uuidString).jpg"
            if persists {
                try? FileManager.default.createDirectory(at: photosFolder, withIntermediateDirectories: true)
                try? data.write(to: photosFolder.appendingPathComponent(name), options: .atomic)
            }
            c.photoFile = name
            if saveToPhotos { Self.copyToPhotosApp(photo) }
        }
        let levelBefore = progress.level
        let earnedBefore = Set(badges.filter(\.earned).map(\.id))
        catches.append(c)
        refresh()
        save()
        let newBadges = badges.filter { $0.earned && !earnedBefore.contains($0.id) }
        guard let award = progress.awards[c.id] else { return nil }
        return SaveResult(savedCatch: c, species: species, award: award, levelBefore: levelBefore,
                          levelAfter: progress.level, xpAfter: progress.totalXP, newBadges: newBadges)
    }

    func delete(_ c: Catch) {
        catches.removeAll { $0.id == c.id }
        if let file = c.photoFile { try? FileManager.default.removeItem(at: photosFolder.appendingPathComponent(file)) }
        refresh()
        save()
    }

    func photo(for c: Catch) -> UIImage? {
        guard let file = c.photoFile else { return nil }
        if let image = UIImage(contentsOfFile: photosFolder.appendingPathComponent(file).path) { return image }
        return demoPhotos[file]
    }

    /// Replaces everything (used for the screenshots' sample data).
    func replaceAll(with catches: [Catch]) {
        self.catches = catches
        refresh()
        save()
    }

    private var demoPhotos: [String: UIImage] = [:]
    func addDemoPhoto(_ image: UIImage, named name: String) { demoPhotos[name] = image }

    // MARK: Backup

    /// A backup file of every catch record (photos stay in the Photos folder).
    func exportFile() -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(ProgressEngine.ordered(catches)) else { return nil }
        let stamp = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FishoDex backup \(stamp).json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: Files

    private var catchesFile: URL { folder.appendingPathComponent("catches.json") }
    private var photosFolder: URL { folder.appendingPathComponent("Photos", isDirectory: true) }

    private func load() {
        guard let data = try? Data(contentsOf: catchesFile) else { return }
        catches = (try? JSONDecoder().decode([Catch].self, from: data)) ?? []
    }

    private func save() {
        guard persists, let data = try? JSONEncoder().encode(catches) else { return }
        try? data.write(to: catchesFile, options: [.atomic, .completeFileProtection])
    }

    private func refresh() {
        progress = ProgressEngine.evaluate(catches, catalog: catalog)
        badges = Badges.evaluate(catches, catalog: catalog)
    }

    private static func copyToPhotosApp(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        }
    }
}
