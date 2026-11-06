import SwiftUI
import UIKit

@main
struct FishoDexApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: CatchStore
    @State private var model = AppModel()

    init() {
        let options = LaunchOptions.current
        let catalog = CatchStore.makeCatalog()
        let store = CatchStore(catalog: catalog, persists: !options.testing,
                               defaults: options.testing ? UserDefaults(suiteName: "uitesting") ?? .standard : .standard)
        if options.demo { store.replaceAll(with: DemoData.catches()) }
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
            .environment(store)
            .environment(model)
            .preferredColorScheme(.light)
            .onAppear {
                model.applyLaunchOptions(catalog: store.catalog)
                let options = LaunchOptions.current
                if let id = options.showUnlock {
                    let draft = Catch(speciesID: id, placeName: "Haulover Inlet", lengthInches: 30,
                                      weightPounds: options.unlockPounds, released: true)
                    model.finishLog(store.add(draft, photo: nil))
                }
            }
        }
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
