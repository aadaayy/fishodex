import SwiftUI
import MapKit

/// Your logbook, newest first, and a map of your own spots that only you see.
struct LogbookView: View {
    @Environment(CatchStore.self) private var store
    @State private var showMap = false

    private var header: some View {
        Text("Logbook").font(Fonts.title(32, relativeTo: .largeTitle)).foregroundStyle(Palette.ink)
    }

    private var countText: some View {
        Text(store.catches.count == 1 ? "1 catch" : "\(store.catches.count) catches").font(Fonts.body(15, .black)).foregroundStyle(Palette.ink)
    }

    var body: some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    header.fixedSize()
                    Spacer(minLength: 8)
                    countText.fixedSize()
                }
                VStack(alignment: .leading, spacing: 2) {
                    header.lineLimit(1).minimumScaleFactor(0.6)
                    countText
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            StickerSegmented(title: "View", selection: $showMap,
                             options: [("List", false), ("Spots map", true)])
            .padding(.horizontal, 16)
            .accessibilityIdentifier("logbook-view")

            if store.catches.isEmpty {
                EmptyLogbook()
                Spacer()
            } else if showMap {
                SpotsMap()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.newestFirst) { c in
                            NavigationLink {
                                CatchDetailView(catchID: c.id)
                            } label: {
                                CatchRow(item: c, showFish: true)
                                    .padding(10)
                                    .sticker(radius: 16, lift: 4)
                            }
                            .buttonStyle(CardPressStyle())
                            .accessibilityIdentifier("logbook-row")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(WaterBackground())
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct EmptyLogbook: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "fish.fill").font(.system(size: 44, weight: .heavy)).foregroundStyle(Palette.ink)
            Text("No catches yet").font(Fonts.title(24)).foregroundStyle(Palette.ink)
            BodyText("Tap Log after your next fish. Pick it from the list, add its size if you have it, and it goes in your dex.")
                .multilineTextAlignment(.center)
            Button("Log a catch") { model.startLog() }
                .buttonStyle(ChunkyButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .sticker()
        .padding(.horizontal, 16)
    }
}

/// One catch: the fish, when, where, how big and the XP it earned.
struct CatchRow: View {
    @Environment(CatchStore.self) private var store
    var item: Catch
    var showFish: Bool

    var body: some View {
        let species = store.catalog[item.speciesID]
        HStack(alignment: .top, spacing: 12) {
            if showFish {
                FishThumb(id: item.isTrophyBass ? SpeciesCatalog.trophyBassID : item.speciesID, size: 56)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    // On a fish's own page the name is already at the top, so the date leads.
                    Text(showFish ? (species?.name ?? item.speciesID) : item.date.formatted(date: .abbreviated, time: .omitted))
                        .font(Fonts.title(18)).foregroundStyle(Palette.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if let xp = store.progress.awards[item.id]?.xp {
                        Text("+\(xp)").font(Fonts.title(16)).foregroundStyle(Palette.ink)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Palette.sun))
                            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2))
                            .fixedSize()
                            .accessibilityLabel("\(xp) XP")
                    }
                }
                if item.isTrophyBass { Pill(text: "Trophy", fill: Rarity.trophy.color, textColor: .white, size: 10) }
                Text(showFish ? item.date.formatted(date: .abbreviated, time: .shortened) : item.date.formatted(date: .omitted, time: .shortened))
                    .font(Fonts.body(13, .bold)).foregroundStyle(Palette.muted)
                let size = store.sizeText(item)
                if size != nil || item.released {
                    HStack(spacing: 6) {
                        if let size {
                            Text(size).font(Fonts.body(14, .extraBold)).foregroundStyle(Palette.ink)
                        }
                        if item.released {
                            Text("Released").font(Fonts.body(12, .black)).foregroundStyle(Palette.good).fixedSize()
                        }
                    }
                }
                if let place = item.placeName, !place.isEmpty {
                    Label(place, systemImage: "mappin")
                        .font(Fonts.body(13, .bold)).foregroundStyle(Palette.muted).lineLimit(2)
                }
                if let cond = item.conditions {
                    ConditionChips(conditions: cond, hasSpot: item.hasSpot).padding(.top, 3)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// The fish on its own, no card, in a round sticker.
struct FishThumb: View {
    var id: String
    var size: CGFloat

    var body: some View {
        Image(id == SpeciesCatalog.trophyBassID ? "fish-trophybass" : "fish-\(id)")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(size * 0.08)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 14).fill(Palette.waterLight.opacity(0.35)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.ink, lineWidth: 2))
            .accessibilityHidden(true)
    }
}

/// A map of your spots. Spots never leave the phone.
struct SpotsMap: View {
    @Environment(CatchStore.self) private var store

    var body: some View {
        let spots = store.newestFirst.filter(\.hasSpot)
        VStack(spacing: 8) {
            if spots.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "map.fill").font(.system(size: 36, weight: .heavy))
                    Text("No spots yet").font(Fonts.title(22))
                    BodyText("Add a spot when you log a catch, with your location or a pin you drop.")
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Palette.ink)
                .padding(20)
                .frame(maxWidth: .infinity)
                .sticker()
                Spacer()
            } else {
                Map(initialPosition: .automatic) {
                    ForEach(spots) { c in
                        Annotation(store.catalog[c.speciesID]?.name ?? "", coordinate: CLLocationCoordinate2D(
                            latitude: c.latitude ?? 0, longitude: c.longitude ?? 0)) {
                            FishThumb(id: c.speciesID, size: 40)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.paper))
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.ink, lineWidth: 3))
                .accessibilityIdentifier("spots-map")
            }
            Label("Only you can see your spots. They stay on this phone.", systemImage: "lock.fill")
                .font(Fonts.body(13, .extraBold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .sticker(radius: 12, lift: 3)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

/// One catch in full, with its photo, and a way to delete it.
struct CatchDetailView: View {
    @Environment(CatchStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var catchID: UUID
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            if let c = store.catches.first(where: { $0.id == catchID }), let s = store.catalog[c.speciesID] {
                VStack(spacing: 14) {
                    if let photo = store.photo(for: c) {
                        Image(uiImage: photo)
                            .resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.ink, lineWidth: 3))
                    } else {
                        FishThumb(id: c.isTrophyBass ? SpeciesCatalog.trophyBassID : s.id, size: 180)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Palette.paper))
                    }
                    InfoPanel(title: s.name, symbol: nil) {
                        VStack(alignment: .leading, spacing: 10) {
                            LabeledLine(label: "When", value: c.date.formatted(date: .long, time: .shortened))
                            if let place = c.placeName, !place.isEmpty { LabeledLine(label: "Place", value: place) }
                            if c.hasSpot { LabeledLine(label: "Spot", value: "Saved on this phone only") }
                            if let w = c.weightPounds { LabeledLine(label: "Weight", value: store.units.weight(w)) }
                            if let l = c.lengthInches { LabeledLine(label: "Length", value: store.units.length(l)) }
                            LabeledLine(label: "Kept or released", value: c.released ? "Released" : "Kept")
                            if let note = c.note, !note.isEmpty { LabeledLine(label: "Note", value: note) }
                            if let award = store.progress.awards[c.id] {
                                LabeledLine(label: "XP", value: award.reasons.map { "\($0.label) +\($0.xp)" }.joined(separator: ", "))
                            }
                        }
                    }
                    ConditionsPanel(item: c)
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Delete this catch", systemImage: "trash.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.paper, text: Palette.ink, size: 17, expand: true))
                    .confirmationDialog("Delete this catch?", isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button("Delete", role: .destructive) {
                            store.delete(c)
                            dismiss()
                        }
                    } message: {
                        Text("Its XP comes off your total. If it was your only \(s.name), the card goes back to a silhouette.")
                    }
                }
                .padding(16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .background(WaterBackground())
        .pageHeader("Catch")
        .tint(Palette.ink)
    }
}
