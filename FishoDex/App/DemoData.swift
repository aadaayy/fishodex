import Foundation

/// Sample catches for the screenshots: a few weeks of fishing around
/// South Florida, with sizes and spots, a Trophy bass and a Grand Slam day.
enum DemoData {
    static func catches(now: Date = AppClock.now) -> [Catch] {
        let cal = Calendar.current
        func day(_ daysAgo: Int, _ hour: Int) -> Date {
            let d = cal.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return cal.date(bySettingHour: hour, minute: 15, second: 0, of: d) ?? d
        }
        func c(_ id: String, _ daysAgo: Int, _ hour: Int, place: String, _ lat: Double, _ lon: Double,
               len: Double? = nil, lb: Double? = nil, released: Bool = false, note: String? = nil) -> Catch {
            Catch(speciesID: id, date: day(daysAgo, hour), placeName: place, latitude: lat, longitude: lon,
                  lengthInches: len, weightPounds: lb, released: released, note: note,
                  createdAt: day(daysAgo, hour))
        }
        return [
            c("bass", 40, 7, place: "Tamiami Canal", 25.7617, -80.5300, len: 16, lb: 2.4, released: true),
            c("peacock", 38, 9, place: "Snapper Creek Canal", 25.7101, -80.3440, len: 15, lb: 2.1),
            c("bluegill", 38, 10, place: "Snapper Creek Canal", 25.7104, -80.3452, len: 7),
            c("mayan", 35, 8, place: "C-111 Canal", 25.2903, -80.4430, len: 8),
            c("oscar", 35, 9, place: "C-111 Canal", 25.2911, -80.4412, len: 9),
            c("snook", 30, 6, place: "Haulover Inlet", 25.9010, -80.1220, len: 29, lb: 8.5, released: true),
            c("graysnapper", 30, 8, place: "Haulover Inlet", 25.9002, -80.1231, len: 12, lb: 1.1),
            c("tarpon", 22, 6, place: "Flamingo", 25.1420, -80.9240, len: 58, released: true,
              note: "Jumped five times"),
            c("bonefish", 22, 10, place: "Flamingo flats", 25.1300, -80.9010, len: 22, released: true),
            c("permit", 22, 14, place: "Flamingo flats", 25.1350, -80.8900, len: 28, lb: 16, released: true,
              note: "Grand Slam day"),
            c("redfish", 21, 9, place: "Whitewater Bay", 25.2400, -80.9100, len: 24, released: true),
            c("mahi", 14, 10, place: "Off Key Biscayne", 25.6500, -80.0500, len: 34, lb: 14),
            c("sailfish", 14, 13, place: "Off Key Biscayne", 25.6400, -80.0400, len: 84, released: true),
            c("lionfish", 10, 11, place: "Pompano reef", 26.2400, -80.0800, len: 11),
            c("bass", 5, 7, place: "Lake Ida", 26.4700, -80.0800, len: 25, lb: 10.6, released: true,
              note: "Trophy bass"),
            c("snook", 2, 19, place: "Haulover Inlet", 25.9012, -80.1221, len: 31, lb: 10.2, released: true),
            c("graysnapper", 1, 20, place: "Haulover Inlet", 25.9005, -80.1225, len: 11),
        ]
    }
}
