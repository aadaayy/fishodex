import SwiftUI
import UIKit

@main
struct FishoDexApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: CatchStore
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let options = LaunchOptions.current
        let catalog = CatchStore.makeCatalog()
        // The checks never go online: they use made-up readings, or none with -offline.
        let mode: CatchStore.ConditionsMode = options.testing ? (options.offline ? .offline : .demo) : .live
        let store = CatchStore(catalog: catalog, persists: !options.testing,
                               defaults: options.testing ? UserDefaults(suiteName: "uitesting") ?? .standard : .standard,
                               conditions: mode)
        if options.demo {
            var catches = DemoConditions.attach(to: DemoData.catches(), catalog: catalog, stations: store.stations)
            // With -offline, the newest sample catch is still waiting for signal.
            if options.offline, let newest = catches.indices.max(by: { catches[$0].date < catches[$1].date }) {
                catches[newest].conditions = CatchConditions.offline(for: catches[newest],
                                                                    habitat: catalog[catches[newest].speciesID]?.habitat)
            }
            store.replaceAll(with: catches)
        }
        if options.testing {
            // The checks start fresh each launch: no tour unless asked for.
            if options.starterDone { store.finishStarterForChecks() }
            store.seenWalkthrough = !options.walkthrough
        }
        _store = State(initialValue: store)
        if options.still { UIView.setAnimationsEnabled(false) }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let size = LaunchOptions.current.previewSize {
                    ScreenPreview(screen: size) { RootView() }
                } else {
                    RootView()
                }
            }
            .modifier(TextSizeOverride(size: LaunchOptions.current.textSize))
            .environment(store)
            .environment(model)
            .preferredColorScheme(.light)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { store.fillWaiting() }
            }
            .task {
                // Catches logged in the last few minutes wait for the stations to post their readings.
                while !Task.isCancelled {
                    store.fillWaiting()
                    try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                }
            }
            .onAppear {
                model.applyLaunchOptions(catalog: store.catalog)
                let options = LaunchOptions.current
                // The starter tour, once, on first launch.
                if !store.seenWalkthrough && options.showUnlock == nil { model.walkthrough = true }
                if let id = options.showUnlock {
                    let draft = Catch(speciesID: id, date: AppClock.now, placeName: "Haulover Inlet", lengthInches: 30,
                                      weightPounds: options.unlockPounds, released: true)
                    model.finishLog(store.add(draft, photo: nil))
                }
            }
        }
    }
}

/// The checks' bigger text size, when they pass one; otherwise the phone's own.
struct TextSizeOverride: ViewModifier {
    let size: DynamicTypeSize?

    func body(content: Content) -> some View {
        if let size { content.dynamicTypeSize(size) } else { content }
    }
}

/// The app drawn at another phone's screen size, shrunk to fit whatever
/// simulator runs it. The automatic checks can't unfold the Duo simulator,
/// so they use this to show the open Duo (about 951 by 669 points).
/// Used only with -openDuoPreview or -previewSize.
struct ScreenPreview<Content: View>: View {
    let screen: CGSize
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / screen.width, geometry.size.height / screen.height)
            content
                .frame(width: screen.width, height: screen.height)
                .clipped()
                .scaleEffect(scale)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black)
        .ignoresSafeArea()
    }
}

/// Regular iPhones stay upright. The iPhone Duo turns freely (folded it's
/// nearly square, and open it's already wide).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.isRegularPhone ? .portrait : .allButUpsideDown
    }

    /// A long, narrow screen (about 2 to 1): every iPhone but the Duo.
    static let isRegularPhone: Bool = {
        let bounds = UIScreen.main.bounds
        let long = max(bounds.width, bounds.height), short = min(bounds.width, bounds.height)
        return long / max(short, 1) > 1.7
    }()
}
