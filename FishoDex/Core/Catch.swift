import Foundation

/// How much of a spot to show if catches are ever shared. Nothing is shared
/// in version 1, so this only records the person's choice.
public enum SpotSharing: String, Codable, CaseIterable, Sendable {
    case hidden, areaName, exact
}

/// How a catch was added. Photo ID comes in a later update.
public enum AddMethod: String, Codable, Sendable {
    case hand, scan
}

/// One fish someone caught and logged.
public struct Catch: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var speciesID: String
    public var date: Date
    public var placeName: String?
    public var latitude: Double?
    public var longitude: Double?
    public var spotSharing: SpotSharing
    public var lengthInches: Double?
    public var weightPounds: Double?
    public var released: Bool
    public var note: String?
    /// File name of the photo in the app's own Photos folder.
    public var photoFile: String?
    /// Kept for photo ID later: how it was added and what the scan suggested.
    public var addedBy: AddMethod
    public var scanSuggestions: [String]
    public var createdAt: Date

    public init(id: UUID = UUID(), speciesID: String, date: Date = Date(), placeName: String? = nil,
                latitude: Double? = nil, longitude: Double? = nil, spotSharing: SpotSharing = .hidden,
                lengthInches: Double? = nil, weightPounds: Double? = nil, released: Bool = false,
                note: String? = nil, photoFile: String? = nil, addedBy: AddMethod = .hand,
                scanSuggestions: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.speciesID = speciesID
        self.date = date
        self.placeName = placeName
        self.latitude = latitude
        self.longitude = longitude
        self.spotSharing = spotSharing
        self.lengthInches = lengthInches
        self.weightPounds = weightPounds
        self.released = released
        self.note = note
        self.photoFile = photoFile
        self.addedBy = addedBy
        self.scanSuggestions = scanSuggestions
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, speciesID, date, placeName, latitude, longitude, spotSharing, lengthInches, weightPounds
        case released, note, photoFile, addedBy, scanSuggestions, createdAt
    }

    // Lenient reading, so older backups still open after new fields are added.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        speciesID = try c.decode(String.self, forKey: .speciesID)
        date = try c.decode(Date.self, forKey: .date)
        placeName = try c.decodeIfPresent(String.self, forKey: .placeName)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        spotSharing = try c.decodeIfPresent(SpotSharing.self, forKey: .spotSharing) ?? .hidden
        lengthInches = try c.decodeIfPresent(Double.self, forKey: .lengthInches)
        weightPounds = try c.decodeIfPresent(Double.self, forKey: .weightPounds)
        released = try c.decodeIfPresent(Bool.self, forKey: .released) ?? false
        note = try c.decodeIfPresent(String.self, forKey: .note)
        photoFile = try c.decodeIfPresent(String.self, forKey: .photoFile)
        addedBy = try c.decodeIfPresent(AddMethod.self, forKey: .addedBy) ?? .hand
        scanSuggestions = try c.decodeIfPresent([String].self, forKey: .scanSuggestions) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? date
    }

    public var hasSpot: Bool { latitude != nil && longitude != nil }

    /// True for a Florida bass of 10 pounds or more.
    public var isTrophyBass: Bool {
        speciesID == SpeciesCatalog.floridaBassID && (weightPounds ?? 0) >= SpeciesCatalog.trophyBassPounds
    }
}
