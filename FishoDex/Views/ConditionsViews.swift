import SwiftUI

extension MoonPhase {
    /// Short words for a chip; the icon shows whether it's growing or shrinking.
    var short: String {
        switch self {
        case .new: return "New moon"
        case .full: return "Full moon"
        case .waxingCrescent, .waningCrescent: return "Crescent"
        case .firstQuarter, .lastQuarter: return "Half moon"
        case .waxingGibbous, .waningGibbous: return "Gibbous"
        }
    }
}

extension TideStage {
    /// "on a rising tide", for a sentence.
    var phrase: String {
        switch self {
        case .low: return "at low tide"
        case .rising: return "on a rising tide"
        case .high: return "at high tide"
        case .falling: return "on a falling tide"
        }
    }
}

extension TimeOfDay {
    var phrase: String {
        switch self {
        case .dawn: return "at dawn"
        case .morning: return "in the morning"
        case .midday: return "around midday"
        case .afternoon: return "in the afternoon"
        case .dusk: return "at dusk"
        case .night: return "at night"
        }
    }
}

extension MoonGroup {
    var phrase: String {
        switch self {
        case .new: return "around the new moon"
        case .waxing: return "while the moon grows"
        case .full: return "around the full moon"
        case .waning: return "while the moon shrinks"
        }
    }
}

/// A catch's conditions as small chips, for the logbook rows.
struct ConditionChips: View {
    @Environment(CatchStore.self) private var store
    var conditions: CatchConditions
    var hasSpot: Bool

    private struct Chip: Identifiable {
        var id: String
        var symbol: String
        var text: String
    }

    private var chips: [Chip] {
        var list: [Chip] = []
        if let tide = conditions.tide { list.append(Chip(id: "tide", symbol: tide.stage.symbol, text: tide.stage.short)) }
        list.append(Chip(id: "moon", symbol: conditions.moon.symbol, text: conditions.moon.short))
        if let wind = conditions.wind { list.append(Chip(id: "wind", symbol: "wind", text: store.units.windSpeed(wind.mph))) }
        if let water = conditions.water {
            list.append(Chip(id: "water", symbol: "thermometer.medium", text: store.units.waterTemp(water.fahrenheit)))
        }
        if hasSpot && conditions.waiting { list.append(Chip(id: "waiting", symbol: "clock.fill", text: "More soon")) }
        return list
    }

    var body: some View {
        WrapLayout(spacing: 5, lineSpacing: 5) {
            ForEach(chips) { chip in
                HStack(spacing: 3) {
                    Image(systemName: chip.symbol).font(.system(size: 10, weight: .heavy))
                    Text(chip.text).font(Fonts.body(12, .black, relativeTo: .caption))
                }
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(chip.id == "waiting" ? Palette.sun.opacity(0.5) : Palette.waterLight.opacity(0.3)))
                .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 1.5))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("condition-chips")
    }
}

/// Lays its views out in rows, starting a new row when the next one doesn't fit.
struct WrapLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    private func rows(_ sizes: [CGSize], width: CGFloat) -> [[Int]] {
        var rows: [[Int]] = [[]]
        var x: CGFloat = 0
        for (i, size) in sizes.enumerated() {
            if !rows[rows.count - 1].isEmpty, x + spacing + size.width > width {
                rows.append([])
                x = 0
            }
            x += (rows[rows.count - 1].isEmpty ? 0 : spacing) + size.width
            rows[rows.count - 1].append(i)
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let width = proposal.width ?? .infinity
        let lines = rows(sizes, width: width)
        var height: CGFloat = 0, widest: CGFloat = 0
        for (n, line) in lines.enumerated() {
            let w = line.map { sizes[$0].width }.reduce(0, +) + spacing * CGFloat(max(line.count - 1, 0))
            widest = max(widest, w)
            height += (line.map { sizes[$0].height }.max() ?? 0) + (n > 0 ? lineSpacing : 0)
        }
        return CGSize(width: proposal.width.map { min($0, widest) } ?? widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var y = bounds.minY
        for line in rows(sizes, width: bounds.width) {
            var x = bounds.minX
            let h = line.map { sizes[$0].height }.max() ?? 0
            for i in line {
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sizes[i]))
                x += sizes[i].width + spacing
            }
            y += h + lineSpacing
        }
    }
}

/// Every condition of one catch, on its detail screen.
struct ConditionsPanel: View {
    @Environment(CatchStore.self) private var store
    var item: Catch

    var body: some View {
        let cond = item.conditions ?? CatchConditions.offline(for: item, habitat: store.catalog[item.speciesID]?.habitat)
        InfoPanel(title: "Conditions", symbol: "water.waves") {
            VStack(alignment: .leading, spacing: 12) {
                if item.hasSpot && cond.waiting {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "clock.fill").foregroundStyle(Palette.orange)
                        BodyText("The rest fills in by itself once the phone is online and the stations have posted their readings.")
                    }
                }
                if !item.hasSpot {
                    note("No spot was saved with this catch, so only the moon and time of day are here. Add your location or a pin next time and FishoDex saves the tide, wind and water temperature too.")
                }
                tideRow(cond)
                ConditionLine(symbol: cond.timeOfDay.symbol, title: "Time of day", value: cond.timeOfDay.label, detail: sunText)
                ConditionLine(symbol: cond.moon.symbol, title: "Moon", value: cond.moon.label,
                              detail: "\(Int((cond.moonLit * 100).rounded()))% lit")
                if item.hasSpot {
                    windRow(cond)
                    waterRow(cond)
                    Text("Tide, wind and water temperature come from NOAA, the National Weather Service and USGS. FishoDex asks them by station, so your spot stays on this phone.")
                        .font(Fonts.body(13, .bold))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("conditions-panel")
    }

    private func note(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "mappin.slash").foregroundStyle(Palette.orange)
            BodyText(text)
        }
    }

    private func miles(_ m: Double) -> String {
        let value = store.units == .us ? m : m * 1.609344
        let unit = store.units == .us ? "mi" : "km"
        return value < 1 ? "under 1 \(unit) away" : "\(Int(value.rounded())) \(unit) away"
    }

    private func time(_ d: Date) -> String { d.formatted(date: .omitted, time: .shortened) }

    private var sunText: String? {
        let lat = item.latitude ?? Sky.southFlorida.latitude, lon = item.longitude ?? Sky.southFlorida.longitude
        let sun = Sky.sun(on: item.date, latitude: lat, longitude: lon)
        guard let rise = sun.rise, let set = sun.set else { return nil }
        return "Sunrise \(time(rise)), sunset \(time(set))"
    }

    @ViewBuilder
    private func tideRow(_ cond: CatchConditions) -> some View {
        switch cond.tideState {
        case .done:
            if let t = cond.tide {
                let turn = { (x: TideTurn, lead: Bool) in
                    "\(x.isHigh ? (lead ? "High" : "high") : (lead ? "Low" : "low")) \(store.units.tideHeight(x.feet)) at \(time(x.time))"
                }
                ConditionLine(symbol: t.stage.symbol, title: "Tide", value: t.stage.label,
                              detail: "\(turn(t.previous, true)), then \(turn(t.next, false)). \(ConditionStation(id: t.stationID, name: t.stationName, lat: 0, lon: 0).shortName) tide station, \(miles(t.miles)).")
            }
        case .waiting:
            ConditionLine(symbol: "clock.fill", title: "Tide", value: "Coming soon", detail: nil)
        case .none:
            ConditionLine(symbol: "water.waves", title: "Tide", value: "No tide station close by", detail: nil)
        case .skipped:
            EmptyView()
        }
    }

    @ViewBuilder
    private func windRow(_ cond: CatchConditions) -> some View {
        switch cond.windState {
        case .done:
            if let w = cond.wind {
                let from = w.compass.map { " from the \($0)" } ?? ""
                let gust = w.gustMph.map { "Gusts \(store.units.windSpeed($0)). " } ?? ""
                ConditionLine(symbol: "wind", title: "Wind", value: w.mph < 1 ? "Calm" : "\(store.units.windSpeed(w.mph))\(from)",
                              detail: "\(gust)\(w.source), \(miles(w.miles)).")
            }
        case .waiting:
            ConditionLine(symbol: "clock.fill", title: "Wind", value: "Coming soon", detail: nil)
        case .none, .skipped:
            ConditionLine(symbol: "wind", title: "Wind", value: "No reading close by", detail: nil)
        }
    }

    @ViewBuilder
    private func waterRow(_ cond: CatchConditions) -> some View {
        switch cond.waterState {
        case .done:
            if let w = cond.water {
                ConditionLine(symbol: "thermometer.medium", title: "Water temperature", value: store.units.waterTemp(w.fahrenheit),
                              detail: "\(w.source), \(miles(w.miles)).")
            }
        case .waiting:
            ConditionLine(symbol: "clock.fill", title: "Water temperature", value: "Coming soon", detail: nil)
        case .none, .skipped:
            ConditionLine(symbol: "thermometer.medium", title: "Water temperature", value: "No gauge close by", detail: nil)
        }
    }
}

/// One condition: an icon, what it is, the reading and where it came from.
struct ConditionLine: View {
    var symbol: String
    var title: String
    var value: String
    var detail: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Palette.waterLight.opacity(0.35)))
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(Fonts.body(11, .black, relativeTo: .caption))
                    .foregroundStyle(Palette.muted)
                Text(value)
                    .font(Fonts.body(16, .extraBold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(Fonts.body(13, .bold))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// When this fish bites best for you, from your own logbook.
struct BestBitePanel: View {
    @Environment(CatchStore.self) private var store
    var species: Species

    var body: some View {
        let bite = store.biteInsight(for: species.id)
        InfoPanel(title: "Your best bite", symbol: "scope") {
            VStack(alignment: .leading, spacing: 12) {
                if !bite.ready {
                    BodyText(bite.needed == 1
                             ? "Log 1 more \(species.name) to see when they bite best for you."
                             : "Log \(bite.needed) more \(species.name) to see when they bite best for you.")
                    HStack(spacing: 6) {
                        ForEach(0..<BiteInsights.minimumCatches, id: \.self) { i in
                            Circle()
                                .fill(i < bite.catches ? Palette.sun : Palette.paperShade)
                                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
                                .frame(width: 20, height: 20)
                        }
                        Text("\(bite.catches) of \(BiteInsights.minimumCatches)")
                            .font(Fonts.body(14, .black)).foregroundStyle(Palette.ink)
                            .padding(.leading, 4)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(bite.catches) of \(BiteInsights.minimumCatches) catches logged")
                    Text("Each catch saves its tide, moon, wind and water temperature by itself.")
                        .font(Fonts.body(13, .bold)).foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else if bite.findings.isEmpty {
                    BodyText("No clear pattern yet in your \(bite.catches) catches. Keep logging and it'll show.")
                } else {
                    if let headline = headline(bite) {
                        Text(headline)
                            .font(Fonts.title(20))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("best-bite-headline")
                    }
                    ForEach(bite.findings) { f in
                        FindingRow(finding: f, label: label(f), symbol: symbol(f))
                    }
                    Text("From your \(bite.catches) catches of it. The more you log, the surer it gets.")
                        .font(Fonts.body(13, .bold)).foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("best-bite")
    }

    /// "Your snook bite best on a rising tide at dawn."
    private func headline(_ bite: BiteInsight) -> String? {
        var parts: [String] = []
        if let t = bite.finding(.tide)?.tide { parts.append(t.phrase) }
        if let d = bite.finding(.time)?.time { parts.append(d.phrase) }
        if parts.count < 2, let m = bite.finding(.moon)?.moon { parts.append(m.phrase) }
        guard !parts.isEmpty else { return nil }
        return "Your \(species.name) bite best \(parts.prefix(2).joined(separator: " "))."
    }

    private func label(_ f: BiteFinding) -> String {
        switch f.factor {
        case .tide: return f.tide?.label ?? ""
        case .time: return f.time?.label ?? ""
        case .moon: return f.moon?.label ?? ""
        case .wind: return f.wind.map { "\($0.label), \($0.range(store.units))" } ?? ""
        case .water: return f.water?.label(store.units) ?? ""
        }
    }

    private func symbol(_ f: BiteFinding) -> String {
        switch f.factor {
        case .tide: return f.tide?.symbol ?? "water.waves"
        case .time: return f.time?.symbol ?? "sun.max.fill"
        case .moon: return f.moon?.symbol ?? "moon.fill"
        case .wind: return "wind"
        case .water: return "thermometer.medium"
        }
    }
}

private struct FindingRow: View {
    var finding: BiteFinding
    var label: String
    var symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                ConditionLine(symbol: symbol, title: finding.factor.title, value: label, detail: nil)
                Text("\(finding.count) of \(finding.outOf)")
                    .font(Fonts.body(13, .black))
                    .foregroundStyle(Palette.ink)
                    .fixedSize()
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Palette.sun))
                    .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2))
            }
            XPBar(fraction: Double(finding.count) / Double(max(finding.outOf, 1)), height: 10)
                .padding(.leading, 44)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("finding-\(finding.factor.rawValue)")
    }
}
