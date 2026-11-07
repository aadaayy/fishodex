import SwiftUI
import PhotosUI
import MapKit
import CoreLocation
import ImageIO

/// Log a catch: identify the fish from a photo or pick it by name, then the
/// details, with what the catch is worth in XP before you save it.
struct LogCatchFlow: View {
    var preset: String?
    var onDone: (SaveResult?) -> Void

    enum Step: Hashable { case picker, identify, details(String) }
    @State private var path: [Step] = []
    /// The photo from photo ID, carried into the details so it stays with the catch.
    /// A shared object, so each screen reads the photo as it is now rather than
    /// a copy from when the screen was set up.
    @State private var scan = ScanDraft()

    var body: some View {
        NavigationStack(path: $path) {
            ChooseMethodView(
                onPick: {
                    clearScan()
                    path.append(.picker)
                },
                onPhoto: { image, info in
                    scan.photo = image
                    scan.info = info
                    scan.guesses = []
                    path.append(.identify)
                },
                onClose: { onDone(nil) })
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .picker:
                        SpeciesPickerView(onChoose: { path.append(.details($0)) }, onClose: { onDone(nil) })
                    case .identify:
                        if let photo = scan.photo {
                            PhotoIDView(photo: photo,
                                        onChoose: { id, guesses in
                                            scan.guesses = guesses
                                            path.append(.details(id))
                                        },
                                        onPickByName: { guesses in
                                            scan.guesses = guesses
                                            path.append(.picker)
                                        },
                                        onClose: { onDone(nil) })
                        }
                    case .details(let id):
                        CatchDetailsForm(speciesID: id, initialPhoto: scan.photo, initialPhotoInfo: scan.info,
                                         scanGuesses: scan.photo == nil ? [] : scan.guesses,
                                         onSave: onDone, onClose: { onDone(nil) })
                    }
                }
        }
        .tint(Palette.ink)
        .onAppear {
            if let preset, path.isEmpty {
                path = [.details(preset)]
            } else if path.isEmpty, let sample = LaunchOptions.takeScanSample() {
                scan.photo = sample
                // Open photo ID on the next turn, once the stack is on screen.
                Task { @MainActor in path = [.identify] }
            }
        }
    }

    private func clearScan() {
        scan.photo = nil
        scan.info = nil
        scan.guesses = []
    }
}

/// The photo being identified, and what photo ID suggested for it.
@Observable
final class ScanDraft {
    var photo: UIImage?
    var info: PhotoInfo?
    var guesses: [String] = []
}


struct CloseButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(.system(size: 15, weight: .black))
                .foregroundStyle(Palette.ink)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Palette.paper))
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2.5))
        }
        .accessibilityLabel("Close")
        .accessibilityIdentifier("close-log")
    }
}

/// The top of each step: back, the step's name and close. Drawn by the app
/// rather than the system bar so it sits the same on every phone.
struct FlowHeader: View {
    @Environment(\.dismiss) private var dismiss
    var title: String
    var onClose: () -> Void

    var body: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 16, weight: .black))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Palette.paper))
                    .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2.5))
            }
            .accessibilityLabel("Back")
            .accessibilityIdentifier("log-back")
            Spacer()
            Text(title).font(Fonts.title(22)).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            CloseButton(action: onClose)
        }
        .padding(.top, 14)
    }
}

// MARK: Step 1

struct ChooseMethodView: View {
    var onPick: () -> Void
    var onPhoto: (UIImage, PhotoInfo?) -> Void
    var onClose: () -> Void
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var loading = false

    private var hasCamera: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Log a catch").font(Fonts.title(32, relativeTo: .largeTitle)).foregroundStyle(Palette.ink)
                    Spacer()
                    CloseButton(action: onClose)
                }
                identifyCard
                Button(action: onPick) {
                    HStack(spacing: 14) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 26, weight: .black))
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Palette.paperShade))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pick the fish").font(Fonts.title(24))
                            Text("Type its name or browse by water")
                                .font(Fonts.body(15, .extraBold))
                                .foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 18, weight: .black))
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(16)
                    .sticker(Palette.paper)
                }
                .buttonStyle(CardPressStyle())
                .accessibilityIdentifier("pick-fish")

                Text("Catches and photos are private and stay on this phone.")
                    .font(Fonts.body(14, .extraBold))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 4)
            }
            .padding(18)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(WaterBackground())
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in onPhoto(image, nil) }
                .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            loading = true
            Task {
                defer { loading = false; photoItem = nil }
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                onPhoto(image, PhotoInfo(data: data))
            }
        }
    }

    private var identifyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 26, weight: .black))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(.white.opacity(0.25)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Identify from photo").font(Fonts.title(24))
                    Text("Snap your fish and FishoDex names it")
                        .font(Fonts.body(15, .extraBold))
                        .opacity(0.9)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .accessibilityElement(children: .combine)
            HStack(spacing: 10) {
                if hasCamera {
                    Button { showCamera = true } label: { Label("Take photo", systemImage: "camera.fill") }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.sun, text: Palette.ink, size: 17, expand: true))
                        .accessibilityIdentifier("identify-camera")
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    if loading {
                        ProgressView().tint(Palette.ink)
                    } else {
                        Label(hasCamera ? "Choose" : "Choose photo", systemImage: "photo.on.rectangle")
                    }
                }
                .buttonStyle(ChunkyButtonStyle(fill: Palette.paper, text: Palette.ink, size: 17, expand: true))
                .accessibilityIdentifier("identify-choose")
            }
        }
        .padding(16)
        .sticker(Palette.orange)
        .accessibilityIdentifier("identify-card")
    }
}

// MARK: Step 2

struct SpeciesPickerView: View {
    @Environment(CatchStore.self) private var store
    var onChoose: (String) -> Void
    var onClose: () -> Void
    @State private var query = ""
    @State private var habitat: Habitat?
    @FocusState private var searching: Bool

    var body: some View {
        let list = store.catalog.search(query, habitat: habitat)
        ScrollView {
            VStack(spacing: 12) {
                FlowHeader(title: "Pick the fish", onClose: onClose)
                SearchField(text: $query, prompt: "Fish name, like snook or mangrove snapper", identifier: "species-search")
                    .focused($searching)
                HStack(spacing: 8) {
                    chip(nil, "All", Palette.sun)
                    ForEach(Habitat.allCases) { chip($0, $0.rawValue, $0.color) }
                }
                if list.isEmpty {
                    VStack(spacing: 6) {
                        Text("No fish called \"\(query)\"").font(Fonts.title(20))
                        BodyText("FishoDex has 63 South Florida fish so far. Try another name, like the one your bait shop uses.")
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .sticker()
                }
                LazyVStack(spacing: 8) {
                    ForEach(list) { s in
                        Button { onChoose(s.id) } label: { PickerRow(species: s) }
                            .buttonStyle(CardPressStyle())
                            .accessibilityIdentifier("species-row-\(s.id)")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(WaterBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func chip(_ h: Habitat?, _ title: String, _ color: Color) -> some View {
        let on = habitat == h
        return Button { habitat = h } label: {
            Text(title)
                .font(Fonts.body(13, .black, relativeTo: .caption))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Capsule().fill(on ? color : Palette.paper))
                .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct PickerRow: View {
    @Environment(CatchStore.self) private var store
    var species: Species

    var body: some View {
        let caught = store.progress.caught.contains(species.id)
        HStack(spacing: 12) {
            FishThumb(id: species.id, size: 58)
            VStack(alignment: .leading, spacing: 2) {
                Text(species.name).font(Fonts.title(18)).foregroundStyle(Palette.ink).lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(species.numberText) · \(species.habitat.rawValue)")
                    .font(Fonts.body(13, .bold)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            if caught {
                Label("In dex", systemImage: "checkmark.circle.fill")
                    .font(Fonts.body(12, .black)).foregroundStyle(Palette.good).labelStyle(.titleAndIcon)
            } else {
                Pill(text: "New +\(species.rarity.newSpeciesXP)", fill: Palette.sun, size: 11)
            }
        }
        .padding(8)
        .sticker(radius: 16, lift: 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Step 3

struct CatchDetailsForm: View {
    @Environment(CatchStore.self) private var store
    @Environment(\.layoutShape) private var layout
    var speciesID: String
    /// The photo photo ID looked at, if the fish was identified from one.
    var initialPhoto: UIImage? = nil
    var initialPhotoInfo: PhotoInfo? = nil
    /// What photo ID suggested, saved with the catch.
    var scanGuesses: [String] = []
    var onSave: (SaveResult?) -> Void
    var onClose: () -> Void

    @State private var draftID = UUID()
    @State private var date = Date()
    @State private var placeName = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var weightText = ""
    @State private var lengthText = ""
    @State private var released = true
    @State private var note = ""
    @State private var photo: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var photoInfo: PhotoInfo?
    @State private var showCamera = false
    @State private var usedInitialPhoto = false
    @State private var showPin = false
    @State private var locator = Locator()
    @FocusState private var focused: Field?

    enum Field { case place, weight, length, note }

    private var species: Species? { store.catalog[speciesID] }

    private var draft: Catch {
        Catch(id: draftID, speciesID: speciesID, date: date,
              placeName: placeName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : placeName,
              latitude: latitude, longitude: longitude,
              lengthInches: UnitSystem.parse(lengthText).map(store.units.inches(fromTyped:)),
              weightPounds: UnitSystem.parse(weightText).map(store.units.pounds(fromTyped:)),
              released: released,
              note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
              addedBy: initialPhoto == nil ? .hand : .scan,
              scanSuggestions: initialPhoto == nil ? [] : scanGuesses)
    }

    var body: some View {
        ScrollView {
            if let s = species {
                VStack(spacing: 14) {
                    FlowHeader(title: "Details", onClose: onClose)
                    header(s)
                    whenAndWhere
                    sizeSection(s)
                    photoSection
                    XPPreview(award: store.preview(draft))
                    Button {
                        focused = nil
                        let result = store.add(draft, photo: photo)
                        onSave(result)
                    } label: {
                        Label("Save catch", systemImage: "checkmark")
                    }
                    .buttonStyle(ChunkyButtonStyle(size: 22, expand: true))
                    .accessibilityIdentifier("save-catch")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(WaterBackground())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = nil }
                    .font(Fonts.body(17, .black))
                    .accessibilityIdentifier("keyboard-done")
            }
        }
        .sheet(isPresented: $showPin) {
            PinDropView(latitude: $latitude, longitude: $longitude, placeName: $placeName)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                photo = image
                photoInfo = nil
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            Task { await loadPhoto(item) }
        }
        .onAppear {
            if photo == nil, let initialPhoto, !usedInitialPhoto {
                usedInitialPhoto = true
                photo = initialPhoto
                photoInfo = initialPhotoInfo
            }
        }
        .onChange(of: locator.result) { _, result in
            guard let result else { return }
            latitude = result.latitude
            longitude = result.longitude
            if placeName.isEmpty, let name = result.name { placeName = name }
        }
    }

    private func header(_ s: Species) -> some View {
        let caught = store.progress.caught.contains(s.id)
        return HStack(spacing: 12) {
            FishThumb(id: s.id, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(s.name).font(Fonts.title(24)).foregroundStyle(Palette.ink).lineLimit(2)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 6) {
                    if caught {
                        Text("You've caught \(store.progress.catchCount[s.id] ?? 0) so far")
                            .font(Fonts.body(14, .extraBold)).foregroundStyle(Palette.muted)
                    } else {
                        Pill(text: "New species", fill: Palette.sun)
                    }
                    if initialPhoto != nil {
                        Pill(text: "Photo ID", fill: Palette.waterLight, size: 11)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .sticker()
    }

    private var whenAndWhere: some View {
        InfoPanel(title: "When and where", symbol: "calendar") {
            VStack(alignment: .leading, spacing: 12) {
                DatePicker("Caught", selection: $date, in: ...Date())
                    .font(Fonts.body(16, .extraBold))
                    .foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("date-picker")
                TextField("", text: $placeName, prompt: Text("Place, like Haulover Inlet (optional)").foregroundStyle(Palette.muted))
                    .focused($focused, equals: .place)
                    .submitLabel(.done)
                    .stickerField()
                    .accessibilityIdentifier("place-field")
                HStack(spacing: 8) {
                    Button {
                        locator.request()
                    } label: {
                        Label(locator.busy ? "Finding…" : "Use my location", systemImage: "location.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.paper, text: Palette.ink, size: 15, expand: true))
                    Button { showPin = true } label: {
                        Label("Drop a pin", systemImage: "mappin.and.ellipse")
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.paper, text: Palette.ink, size: 15, expand: true))
                }
                if latitude != nil {
                    HStack {
                        Label("Spot saved. Only you can see it.", systemImage: "lock.fill")
                            .font(Fonts.body(14, .extraBold)).foregroundStyle(Palette.good)
                        Spacer()
                        Button("Remove") { latitude = nil; longitude = nil }
                            .font(Fonts.body(14, .black)).foregroundStyle(Palette.ink)
                    }
                } else if let error = locator.error {
                    Text(error).font(Fonts.body(13, .bold)).foregroundStyle(Palette.muted)
                }
            }
        }
    }

    private func sizeSection(_ s: Species) -> some View {
        InfoPanel(title: "Size and details", symbol: "ruler.fill") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    numberField("Weight", unit: store.units.weightUnit, text: $weightText, field: .weight, id: "weight-field")
                    numberField("Length", unit: store.units.lengthUnit, text: $lengthText, field: .length, id: "length-field")
                }
                Text("Both are optional. Add them if you have them.")
                    .font(Fonts.body(13, .bold)).foregroundStyle(Palette.muted)
                if s.id == SpeciesCatalog.floridaBassID {
                    Label("10 lb or more unlocks the Trophy bass card.", systemImage: "trophy.fill")
                        .font(Fonts.body(14, .black)).foregroundStyle(Rarity.trophy.color)
                }
                Picker("Kept or released", selection: $released) {
                    Text("Released").tag(true)
                    Text("Kept").tag(false)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("released-picker")
                if !released, let kind = s.limits?.kind, kind == "release" {
                    Label("Florida says this fish is catch and release only.", systemImage: "exclamationmark.triangle.fill")
                        .font(Fonts.body(14, .black)).foregroundStyle(Palette.orange)
                }
                TextField("", text: $note, prompt: Text("Note, like the bait you used (optional)").foregroundStyle(Palette.muted), axis: .vertical)
                    .focused($focused, equals: .note)
                    .lineLimit(1...4)
                    .stickerField()
                    .accessibilityIdentifier("note-field")
            }
        }
    }

    private func numberField(_ title: String, unit: String, text: Binding<String>, field: Field, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(Fonts.body(11, .black, relativeTo: .caption)).foregroundStyle(Palette.muted)
            HStack(spacing: 4) {
                TextField("", text: text, prompt: Text("0").foregroundStyle(Palette.muted.opacity(0.6)))
                    .keyboardType(.decimalPad)
                    .focused($focused, equals: field)
                    .accessibilityIdentifier(id)
                    .accessibilityLabel("\(title) in \(unit == "lb" ? "pounds" : unit == "in" ? "inches" : unit)")
                Text(unit).font(Fonts.body(15, .black)).foregroundStyle(Palette.muted)
            }
            .stickerField()
        }
    }

    private var photoSection: some View {
        InfoPanel(title: "Photo", symbol: "camera.fill") {
            VStack(alignment: .leading, spacing: 10) {
                if let photo {
                    Image(uiImage: photo)
                        .resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2.5))
                    if let info = photoInfo, info.date != nil || info.latitude != nil {
                        Button {
                            if let d = info.date { date = min(d, Date()) }
                            if let lat = info.latitude, let lon = info.longitude {
                                latitude = lat
                                longitude = lon
                            }
                            photoInfo = nil
                        } label: {
                            Label("Use the photo's date and place", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.sun, text: Palette.ink, size: 15, expand: true))
                    }
                    Button("Remove photo") { self.photo = nil; photoItem = nil; photoInfo = nil }
                        .font(Fonts.body(14, .black)).foregroundStyle(Palette.ink)
                } else {
                    Text("Optional. It stays on this phone.")
                        .font(Fonts.body(14, .bold)).foregroundStyle(Palette.muted)
                }
                HStack(spacing: 8) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choose", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.paper, text: Palette.ink, size: 15, expand: true))
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showCamera = true } label: { Label("Take one", systemImage: "camera") }
                            .buttonStyle(ChunkyButtonStyle(fill: Palette.paper, text: Palette.ink, size: 15, expand: true))
                    }
                }
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        photo = image
        photoInfo = PhotoInfo(data: data)
    }
}

/// What a catch is worth, shown before saving.
struct XPPreview: View {
    var award: CatchAward?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("This catch is worth").font(Fonts.body(14, .extraBold)).foregroundStyle(Palette.ink)
                ForEach(award?.reasons ?? [], id: \.self) { r in
                    Text("\(r.label) +\(r.xp)").font(Fonts.body(14, .bold)).foregroundStyle(Palette.ink)
                }
            }
            Spacer(minLength: 0)
            Text("+\(award?.xp ?? 0) XP")
                .font(Fonts.title(30))
                .foregroundStyle(Palette.ink)
        }
        .padding(14)
        .sticker(Palette.sun)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("xp-preview")
    }
}

/// The date and place a photo carries, if any.
struct PhotoInfo: Equatable {
    var date: Date?
    var latitude: Double?
    var longitude: Double?

    init?(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let text = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy:MM:dd HH:mm:ss"
            date = f.date(from: text)
        }
        if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
           let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
           let lon = gps[kCGImagePropertyGPSLongitude] as? Double {
            latitude = (gps[kCGImagePropertyGPSLatitudeRef] as? String) == "S" ? -lat : lat
            longitude = (gps[kCGImagePropertyGPSLongitudeRef] as? String) == "W" ? -lon : lon
        }
        if date == nil && latitude == nil { return nil }
    }
}

/// Finds where you are once, and names the area.
@MainActor
@Observable
final class Locator: NSObject, CLLocationManagerDelegate {
    struct Result: Equatable {
        var latitude: Double
        var longitude: Double
        var name: String?
    }

    var result: Result?
    var busy = false
    var error: String?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        error = nil
        busy = true
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            busy = false
            error = "Location is off for FishoDex. You can drop a pin instead."
        default: manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard self.busy else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
            case .denied, .restricted:
                self.busy = false
                self.error = "Location is off for FishoDex. You can drop a pin instead."
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            let name = await Self.areaName(for: loc)
            self.result = Result(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude, name: name)
            self.busy = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.busy = false
            self.error = "Couldn't find your location. You can drop a pin instead."
        }
    }

    static func areaName(for location: CLLocation) async -> String? {
        let marks = try? await CLGeocoder().reverseGeocodeLocation(location)
        guard let m = marks?.first else { return nil }
        return m.inlandWater ?? m.ocean ?? m.locality ?? m.subAdministrativeArea
    }
}

/// Tap the map to drop a pin on your spot.
struct PinDropView: View {
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var placeName: String
    @Environment(\.dismiss) private var dismiss
    @State private var pin: CLLocationCoordinate2D?
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.9, longitude: -80.4),
        span: MKCoordinateSpan(latitudeDelta: 1.6, longitudeDelta: 1.6)))

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $position) {
                    if let pin { Marker("Your spot", systemImage: "fish.fill", coordinate: pin).tint(Palette.orange) }
                }
                .onTapGesture { point in
                    if let c = proxy.convert(point, from: .local) { pin = c }
                }
            }
            .safeAreaInset(edge: .top) {
                Text(pin == nil ? "Tap the map where you caught it." : "Tap again to move the pin.")
                    .font(Fonts.body(15, .black)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .sticker(radius: 12, lift: 3)
                    .padding(.top, 6)
            }
            .navigationTitle("Drop a pin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let pin {
                            latitude = pin.latitude
                            longitude = pin.longitude
                            if placeName.isEmpty {
                                Task {
                                    let name = await Locator.areaName(for: CLLocation(latitude: pin.latitude, longitude: pin.longitude))
                                    if placeName.isEmpty, let name { placeName = name }
                                }
                            }
                        }
                        dismiss()
                    }
                    .disabled(pin == nil)
                }
            }
            .onAppear {
                if let latitude, let longitude {
                    let c = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    pin = c
                    position = .region(MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)))
                }
            }
        }
    }
}

/// The phone's camera, for a photo of the catch.
struct CameraPicker: UIViewControllerRepresentable {
    var onPhoto: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onPhoto(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
