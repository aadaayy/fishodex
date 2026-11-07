import SwiftUI

extension SeasonEvent {
    var color: Color { Color(hex: colorHex) }
    var cardImage: String { "event-\(id)" }
    var lockedImage: String { "eventlock-\(id)" }
}

/// Dates and counts for one event as of today.
struct EventStatus {
    var event: SeasonEvent
    var on: Bool
    var startYear: Int
    var start: Date
    var end: Date
    var progress: Int
    var done: Bool
    /// Days left (on) or days until it starts (not on).
    var days: Int

    @MainActor
    init(_ event: SeasonEvent, store: CatchStore, today: Date = AppClock.now) {
        let cal = Calendar.current
        self.event = event
        if let year = event.range.startYear(of: today, calendar: cal) {
            on = true
            startYear = year
        } else {
            on = false
            startYear = cal.component(.year, from: event.range.nextStart(after: today, calendar: cal))
        }
        (start, end) = event.range.dates(startingIn: startYear, calendar: cal)
        progress = store.progress.eventProgress(event, startYear: startYear)
        done = store.progress.eventDone(event, startYear: startYear)
        days = Seasons.days(from: today, to: on ? end : start, calendar: cal)
    }

    var timeText: String {
        if on {
            switch days {
            case 0: return "Last day today"
            case 1: return "Ends tomorrow"
            default: return "Ends in \(days) days"
            }
        }
        return days == 1 ? "Starts tomorrow" : "Starts in \(days) days"
    }
}

/// Seasons and events: what's on now, what's next, the year at a glance,
/// the limited event cards and which fish are closed today.
struct EventsView: View {
    @Environment(CatchStore.self) private var store
    var onSelect: (DexCard) -> Void

    var body: some View {
        let today = AppClock.now
        let active = Seasons.active(on: today)
        let upcoming = Seasons.upcoming(after: today)
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Events").font(Fonts.title(32, relativeTo: .largeTitle)).foregroundStyle(Palette.ink)
                    Text("South Florida's fishing seasons. They come back every year.")
                        .font(Fonts.body(15, .extraBold))
                        .foregroundStyle(Palette.ink.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                SectionLabel(text: active.count == 1 ? "On now" : "On now (\(active.count))")
                ForEach(active) { event in
                    ActiveEventPanel(status: EventStatus(event, store: store, today: today), onSelect: onSelect)
                }

                SectionLabel(text: "Coming up")
                VStack(spacing: 0) {
                    ForEach(Array(upcoming.prefix(3).enumerated()), id: \.element.event.id) { index, next in
                        if index > 0 { Divider().overlay(Palette.ink.opacity(0.2)).padding(.horizontal, 14) }
                        UpcomingRow(status: EventStatus(next.event, store: store, today: today))
                    }
                }
                .sticker()

                SeasonCalendar(today: today)
                EventCardsPanel()
                ClosedNowPanel(today: today, onSelect: onSelect)

                Text("Event dates follow the seasons every year. Closed seasons were checked with FWC on \(Self.checkedText). Rules change, so check FWC before you keep a fish.")
                    .font(Fonts.body(12, .bold, relativeTo: .caption))
                    .foregroundStyle(Palette.ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(WaterBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    static var checkedText: String {
        let parts = Seasons.checkedOn.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return Seasons.checkedOn }
        return "\(YearlyRange.months[parts[1] - 1]) \(parts[2]), \(parts[0])"
    }
}

struct SectionLabel: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(Fonts.body(14, .black, relativeTo: .headline))
            .kerning(1)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, -6)
            .accessibilityAddTraits(.isHeader)
    }
}

/// One event that's on: its card, dates, what to catch, progress and reward.
struct ActiveEventPanel: View {
    @Environment(CatchStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.layoutShape) private var layout
    var status: EventStatus
    var onSelect: (DexCard) -> Void

    var body: some View {
        let event = status.event
        let counted = Set((store.progress.eventCatches[event.key(startYear: status.startYear)] ?? []).map(\.speciesID))
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(status.done ? event.cardImage : event.lockedImage)
                    .resizable()
                    .aspectRatio(600 / 780, contentMode: .fit)
                    .frame(width: layout == .folded ? 64 : 92)
                    .shadow(color: Palette.ink.opacity(0.35), radius: 0, x: 0, y: 3)
                    .accessibilityLabel("\(event.name) card, \(status.done ? "earned" : "not earned yet")")
                VStack(alignment: .leading, spacing: 6) {
                    // Side by side, or stacked when the column is narrow (folded Duo).
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) { pills(status) }
                        VStack(alignment: .leading, spacing: 4) { pills(status) }
                    }
                    Text(event.name)
                        .font(Fonts.title(layout == .folded ? 20 : 24))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(event.range.text)
                        .font(Fonts.body(14, .extraBold))
                        .foregroundStyle(Palette.muted)
                    Label(status.timeText, systemImage: "clock.fill")
                        .font(Fonts.body(14, .black))
                        .foregroundStyle(Palette.ink)
                }
                Spacer(minLength: 0)
            }

            BodyText(event.about)

            VStack(alignment: .leading, spacing: 8) {
                Text(event.goalText(names: { store.catalog[$0]?.name ?? $0 }))
                    .font(Fonts.body(16, .black))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    EventBar(fraction: Double(status.progress) / Double(max(event.goal.count, 1)), color: event.color)
                    Text("\(status.progress) of \(event.goal.count)")
                        .font(Fonts.title(18))
                        .foregroundStyle(Palette.ink)
                        .fixedSize()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(status.progress) of \(event.goal.count) done")
                .accessibilityIdentifier("event-progress-\(event.id)")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(event.goal.species, id: \.self) { id in
                        if let s = store.catalog[id] {
                            Button { onSelect(.species(s)) } label: {
                                FishChip(species: s, counted: counted.contains(id), color: event.color)
                            }
                            .buttonStyle(CardPressStyle())
                        }
                    }
                }
                if let rule = ruleNote(event) {
                    Label(rule, systemImage: "arrow.uturn.backward.circle.fill")
                        .font(Fonts.body(13, .extraBold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "gift.fill").font(.system(size: 18, weight: .heavy))
                Text(status.done ? "You earned +\(event.rewardXP) XP and the \(event.name) card."
                                 : "Finish it for +\(event.rewardXP) XP and the limited \(event.name) card.")
                    .font(Fonts.body(14, .extraBold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.ink)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.sun.opacity(0.45)))

            if !status.done {
                Button {
                    model.startLog()
                } label: {
                    Label("Log a catch", systemImage: "plus")
                }
                .buttonStyle(ChunkyButtonStyle(size: 17, expand: true))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker()
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18, style: .continuous)
                .fill(event.color)
                .frame(height: 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink).frame(height: 3) }
                .padding(.horizontal, 3)
                .padding(.top, 3)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("event-\(event.id)")
    }

    @ViewBuilder
    private func pills(_ status: EventStatus) -> some View {
        Pill(text: status.event.season.rawValue, fill: status.event.color, size: 11).fixedSize()
        if status.done { Pill(text: "Finished", fill: Palette.good, size: 11).fixedSize() }
    }

    private func ruleNote(_ event: SeasonEvent) -> String? {
        if event.goal.releasedOnly { return "Only released fish count." }
        func list(_ ids: [String]) -> String {
            let names = ids.compactMap { store.catalog[$0]?.name }
            guard names.count > 1 else { return names.first ?? "" }
            return names.dropLast().joined(separator: ", ") + " and " + names.last!
        }
        var notes: [String] = []
        let closable = event.goal.species.filter { !Seasons.closures(for: $0).isEmpty && !Seasons.releaseOnly.contains($0) }
        if !closable.isEmpty { notes.append("A kept \(list(closable)) doesn't count while its season is closed.") }
        let alwaysBack = event.goal.species.filter { Seasons.releaseOnly.contains($0) }
        if !alwaysBack.isEmpty { notes.append("\(list(alwaysBack)) always go back, so only released ones count.") }
        return notes.isEmpty ? nil : notes.joined(separator: " ")
    }
}

/// A fish that counts toward an event, ticked once it has counted this year.
struct FishChip: View {
    var species: Species
    var counted: Bool
    var color: Color

    var body: some View {
        VStack(spacing: 2) {
            Image("fish-\(species.id)")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 46, height: 30)
            Text(species.name)
                .font(Fonts.body(12, .black, relativeTo: .caption))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity, minHeight: 78)
        .overlay(alignment: .topTrailing) {
            Image(systemName: counted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(counted ? Palette.good : Palette.muted.opacity(0.5))
                .padding(5)
        }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(counted ? color.opacity(0.28) : Palette.paperShade))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(species.name), \(counted ? "counted" : "not yet")")
    }
}

/// A progress bar in the event's colour.
struct EventBar: View {
    var fraction: Double
    var color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.paperShade)
                Capsule().fill(color)
                    .frame(width: max(16, geo.size.width * min(max(fraction, 0), 1)))
                    .opacity(fraction <= 0 ? 0 : 1)
                Capsule().strokeBorder(Palette.ink, lineWidth: 2.5)
            }
        }
        .frame(height: 16)
    }
}

struct UpcomingRow: View {
    var status: EventStatus

    var body: some View {
        let event = status.event
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(event.color)
                Circle().strokeBorder(Palette.ink, lineWidth: 2.5)
                Image(systemName: event.symbol).font(.system(size: 17, weight: .heavy)).foregroundStyle(Palette.ink)
            }
            .frame(width: 42, height: 42)
            // Side by side when there's room; on narrow screens (the folded
            // Duo, big text) the start date goes under the name.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) {
                    names.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 8)
                    Text(status.timeText)
                        .font(Fonts.body(13, .black))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 110, alignment: .trailing)
                }
                VStack(alignment: .leading, spacing: 4) {
                    names
                    Text(status.timeText)
                        .font(Fonts.body(13, .black))
                        .foregroundStyle(Palette.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(status.event.name).font(Fonts.title(19)).foregroundStyle(Palette.ink)
            Text(status.event.range.text).font(Fonts.body(13, .extraBold)).foregroundStyle(Palette.muted)
        }
    }
}

/// The year at a glance: one bar per event across twelve months, with a line for today.
struct SeasonCalendar: View {
    @Environment(\.layoutShape) private var layout
    var today: Date
    @State private var monthRowHeight: CGFloat = 16
    private var nameWidth: CGFloat { layout == .folded ? 84 : 112 }
    private let months = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    var body: some View {
        let cal = Calendar.current
        let year = cal.component(.year, from: today)
        let todayX = dayOfYear(today, cal)
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(text: "The year in events", symbol: "calendar")
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Color.clear.frame(width: 1, height: 1)
                    HStack(spacing: 0) {
                        ForEach(Array(months.enumerated()), id: \.offset) { i, m in
                            Text(m)
                                .font(Fonts.body(11, .black, relativeTo: .caption))
                                .foregroundStyle(i == cal.component(.month, from: today) - 1 ? Palette.orange : Palette.muted)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { monthRowHeight = $0 }
                }
                ForEach(Seasons.events) { event in
                    GridRow {
                        Text(event.name)
                            .font(Fonts.body(12, .black, relativeTo: .caption))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(layout == .folded ? 2 : 1)
                            .minimumScaleFactor(0.75)
                            .frame(width: nameWidth, alignment: .leading)
                        GeometryReader { geo in
                            let w = geo.size.width
                            ZStack(alignment: .leading) {
                                Capsule().fill(Palette.paperShade).frame(height: 14)
                                ForEach(Array(segments(event, year: year, cal).enumerated()), id: \.offset) { _, seg in
                                    Capsule()
                                        .fill(event.color)
                                        .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2))
                                        .frame(width: max(10, w * (seg.1 - seg.0)), height: 14)
                                        .offset(x: w * seg.0)
                                }
                            }
                            .frame(height: 18)
                        }
                        .frame(height: 18)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(event.name), \(event.range.text)")
                }
            }
            .overlay(alignment: .topLeading) {
                // A line for today across the bars.
                // It starts under the month letters, so it never crosses them.
                GeometryReader { geo in
                    let barStart = nameWidth + 10.0
                    let x = barStart + (geo.size.width - barStart) * todayX
                    let top = monthRowHeight + 4
                    Capsule().fill(Palette.orange).frame(width: 3, height: max(0, geo.size.height - top))
                        .offset(x: x - 1.5, y: top)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            HStack(spacing: 6) {
                Capsule().fill(Palette.orange).frame(width: 3, height: 14)
                Text("Today")
                    .font(Fonts.body(12, .black, relativeTo: .caption))
                    .foregroundStyle(Palette.orange)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("season-calendar")
    }

    private func dayOfYear(_ date: Date, _ cal: Calendar) -> Double {
        let day = Double(cal.ordinality(of: .day, in: .year, for: date) ?? 1)
        return (day - 0.5) / 365
    }

    /// The event's stretch as fractions of the year (two pieces if it runs over New Year).
    private func segments(_ event: SeasonEvent, year: Int, _ cal: Calendar) -> [(Double, Double)] {
        let r = event.range
        let s = dayOfYear(cal.date(from: DateComponents(year: year, month: r.startMonth, day: r.startDay)) ?? Date(), cal)
        let endDay = min(r.endDay, r.endMonth == 2 ? 28 : r.endDay)
        let e = dayOfYear(cal.date(from: DateComponents(year: year, month: r.endMonth, day: endDay)) ?? Date(), cal) + 1 / 365
        return r.wraps ? [(0, e), (s, 1)] : [(s, e)]
    }
}

/// The eight limited cards, earned or still to earn, with the years you finished each.
struct EventCardsPanel: View {
    @Environment(CatchStore.self) private var store

    var body: some View {
        let earned = Seasons.events.filter { store.progress.hasEventCard($0) }.count
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(text: "Event cards", symbol: "rectangle.stack.fill")
                Spacer()
                Text("\(earned) of \(Seasons.events.count)")
                    .font(Fonts.body(14, .black))
                    .foregroundStyle(Palette.ink)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92, maximum: 140), spacing: 10, alignment: .top)], spacing: 12) {
                ForEach(Seasons.events) { event in
                    let years = store.progress.yearsDone(event)
                    VStack(spacing: 4) {
                        Image(years.isEmpty ? event.lockedImage : event.cardImage)
                            .resizable()
                            .aspectRatio(600 / 780, contentMode: .fit)
                            .shadow(color: Palette.ink.opacity(0.3), radius: 0, x: 0, y: 3)
                        Text(years.isEmpty ? event.range.text : years.map(yearText).joined(separator: ", "))
                            .font(Fonts.body(11, .black, relativeTo: .caption))
                            .foregroundStyle(years.isEmpty ? Palette.muted : Palette.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(event.name) card, \(years.isEmpty ? "not earned yet" : "earned")")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("event-cards")
    }

    private func yearText(_ startYear: Int) -> String {
        // An event over New Year is named by both years, like 2026-27.
        String(startYear)
    }
}

/// Fish in the dex that can't be kept today somewhere in South Florida.
struct ClosedNowPanel: View {
    @Environment(CatchStore.self) private var store
    var today: Date
    var onSelect: (DexCard) -> Void

    var body: some View {
        let closed = store.catalog.species.compactMap { s -> (Species, [Closure])? in
            let c = Seasons.closedOn(today, speciesID: s.id)
            return c.isEmpty ? nil : (s, c)
        }
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(text: "Closed seasons today", symbol: "hand.raised.fill")
            if closed.isEmpty {
                BodyText("No fish in the dex has a closed season today in South Florida.")
            } else {
                Text("Catch and release only in these places today.")
                    .font(Fonts.body(14, .extraBold))
                    .foregroundStyle(Palette.muted)
                ForEach(closed, id: \.0.id) { s, closures in
                    Button { onSelect(.species(s)) } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Image("fish-\(s.id)")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 48, height: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.name).font(Fonts.title(18)).foregroundStyle(Palette.ink)
                                ForEach(closures, id: \.self) { c in
                                    Text("Closed \(c.range.text) in \(c.area)")
                                        .font(Fonts.body(13, .bold))
                                        .foregroundStyle(Palette.ink)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.system(size: 14, weight: .heavy)).foregroundStyle(Palette.muted)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.paperShade))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(CardPressStyle())
                    .accessibilityIdentifier("closed-\(s.id)")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("closed-now")
    }
}

/// The event that's on, on top of the dex. Tapping it opens Events.
struct EventBanner: View {
    @Environment(CatchStore.self) private var store
    @Environment(AppModel.self) private var model

    var body: some View {
        let today = AppClock.now
        let active = Seasons.active(on: today).map { EventStatus($0, store: store, today: today) }
        // The first one still to finish, or the first one if they're all done.
        if let status = active.first(where: { !$0.done }) ?? active.first {
            let event = status.event
            Button { model.tab = .events } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(event.color)
                        Circle().strokeBorder(Palette.ink, lineWidth: 2.5)
                        Image(systemName: event.symbol).font(.system(size: 18, weight: .heavy)).foregroundStyle(Palette.ink)
                    }
                    .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(event.name).font(Fonts.title(19)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
                            if active.count > 1 { Pill(text: "+\(active.count - 1) more", fill: Palette.paperShade, size: 10) }
                        }
                        Text(status.done ? "Finished. Card earned." : "\(status.progress) of \(event.goal.count) · \(status.timeText)")
                            .font(Fonts.body(13, .extraBold))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 15, weight: .heavy)).foregroundStyle(Palette.ink)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .sticker(Palette.paper, radius: 16, lift: 4)
                .overlay(alignment: .leading) {
                    UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16, style: .continuous)
                        .fill(event.color)
                        .frame(width: 8)
                        .padding(.vertical, 3)
                        .padding(.leading, 3)
                        .padding(.bottom, 4)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(CardPressStyle())
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("event-banner")
        }
    }
}

/// On a fish's page: whether it's closed today, and the events it counts toward.
struct SeasonNowPanel: View {
    @Environment(CatchStore.self) private var store
    @Environment(AppModel.self) private var model
    var species: Species

    var body: some View {
        let today = AppClock.now
        let closed = Seasons.closedOn(today, speciesID: species.id)
        let events = Seasons.active(on: today).filter { $0.goal.species.contains(species.id) }
        if !closed.isEmpty || !events.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                if !closed.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "hand.raised.fill").font(.system(size: 20, weight: .heavy)).foregroundStyle(Palette.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Closed season today").font(Fonts.title(20)).foregroundStyle(Palette.ink)
                            ForEach(closed, id: \.self) { c in
                                Text("Closed \(c.range.text) in \(c.area).")
                                    .font(Fonts.body(14, .extraBold))
                                    .foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text("Catch and release only there.")
                                .font(Fonts.body(14, .bold))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("closed-today")
                }
                ForEach(events) { event in
                    let status = EventStatus(event, store: store, today: today)
                    Button { model.tab = .events } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(event.color)
                                Circle().strokeBorder(Palette.ink, lineWidth: 2)
                                Image(systemName: event.symbol).font(.system(size: 14, weight: .heavy)).foregroundStyle(Palette.ink)
                            }
                            .frame(width: 34, height: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Counts toward \(event.name)").font(Fonts.body(15, .black)).foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(status.done ? "Finished this year" : "\(status.progress) of \(event.goal.count) · \(status.timeText)")
                                    .font(Fonts.body(13, .bold)).foregroundStyle(Palette.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .heavy)).foregroundStyle(Palette.muted)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("counts-toward-\(event.id)")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sticker(closed.isEmpty ? Palette.paper : Color(hex: 0xFFE8D6))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("season-now")
        }
    }
}
