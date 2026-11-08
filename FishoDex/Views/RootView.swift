import SwiftUI

/// Picks the layout for the screen:
/// - iPhone 18 Pro and Pro Max (upright): a bottom bar with a big round Log button.
/// - Folded Duo (nearly square): the right side bar, like his other apps.
/// - Open Duo (wide): a slim rail on the left, the tab on the left half and
///   the fish's card (or Log a catch) on the right half.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let fullW = size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing
            let fullH = size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            let shape: LayoutShape = fullW > fullH * 1.2 ? .open : (fullH / max(fullW, 1) < 1.6 ? .folded : .phone)
            ZStack {
                WaterBackground()
                switch shape {
                case .phone: PhoneLayout()
                case .folded: FoldedLayout()
                case .open: OpenLayout()
                }
                if let result = model.unlock {
                    UnlockView(result: result) { model.unlock = nil }
                        .transition(.opacity)
                        .zIndex(2)
                }
                if model.walkthrough {
                    WalkthroughView()
                        .transition(.opacity)
                        .zIndex(3)
                }
            }
            .environment(\.layoutShape, shape)
        }
    }
}

enum LayoutShape { case phone, folded, open }

private struct LayoutShapeKey: EnvironmentKey {
    static let defaultValue: LayoutShape = .phone
}

extension EnvironmentValues {
    var layoutShape: LayoutShape {
        get { self[LayoutShapeKey.self] }
        set { self[LayoutShapeKey.self] = newValue }
    }
}

/// The tab's screen, with pushed fish pages on phones and the folded Duo.
struct TabContent: View {
    @Environment(AppModel.self) private var model
    var pushes = true

    var body: some View {
        @Bindable var model = model
        switch model.tab {
        case .dex:
            if pushes {
                NavigationStack(path: $model.dexPath) {
                    DexView { model.dexPath.append($0) }
                        .navigationDestination(for: DexCard.self) { SpeciesPage(card: $0) }
                }
            } else {
                NavigationStack { DexView { model.selected = $0 } }
            }
        case .events:
            if pushes {
                NavigationStack(path: $model.eventsPath) {
                    EventsView { model.eventsPath.append($0) }
                        .navigationDestination(for: DexCard.self) { SpeciesPage(card: $0) }
                }
            } else {
                NavigationStack { EventsView { model.selected = $0 } }
            }
        case .logbook:
            NavigationStack { LogbookView() }
        case .profile:
            NavigationStack { ProfileView() }
        }
    }
}

// MARK: Phones

struct PhoneLayout: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            TabContent()
                .noTopScrollBlur()
                .statusBarStrip()
            BottomBar()
        }
        // The keyboard covers the bar instead of pushing it up over the dex.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $model.logging) {
            LogCatchFlow(preset: model.logPreset) { model.finishLog($0) }
                .presentationDragIndicator(.visible)
                .modifier(TextSizeOverride(size: LaunchOptions.current.textSize))
        }
    }
}

struct BottomBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            TabButton(tab: .dex)
            TabButton(tab: .events)
            LogButton(size: 72).offset(y: -14).frame(maxWidth: .infinity)
            TabButton(tab: .logbook)
            TabButton(tab: .profile)
        }
        // Five tabs share the bar, so their labels stop growing at xxLarge.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .background {
            Palette.paper
                .overlay(alignment: .top) { Rectangle().fill(Palette.ink).frame(height: 3) }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: Folded Duo

struct FoldedLayout: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 0) {
            TabContent()
                .noTopScrollBlur()
                .statusBarStrip()
            SideBar()
        }
        .sheet(isPresented: $model.logging) {
            LogCatchFlow(preset: model.logPreset) { model.finishLog($0) }
                .modifier(TextSizeOverride(size: LaunchOptions.current.textSize))
        }
    }
}

struct SideBar: View {
    var body: some View {
        VStack(spacing: 10) {
            TabButton(tab: .dex)
            TabButton(tab: .events)
            LogButton(size: 64).padding(.vertical, 6)
            TabButton(tab: .logbook)
            TabButton(tab: .profile)
            Spacer(minLength: 0)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .padding(.top, 14)
        .frame(width: 96)
        .background {
            Palette.paper
                .overlay(alignment: .leading) { Rectangle().fill(Palette.ink).frame(width: 3) }
                .ignoresSafeArea(edges: [.top, .bottom, .trailing])
        }
    }
}

// MARK: Open Duo

struct OpenLayout: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            Rail()
            TabContent(pushes: false)
                .noTopScrollBlur()
                .statusBarStrip()
                .frame(maxWidth: .infinity)
            Rectangle().fill(Palette.ink).frame(width: 3).ignoresSafeArea()
            Group {
                if model.logging {
                    LogCatchFlow(preset: model.logPreset) { model.finishLog($0) }
                        .id(model.logPreset ?? "log")
                } else if let card = model.selected {
                    NavigationStack { SpeciesPage(card: card) }
                        .id(card.id)
                } else {
                    Color.clear
                }
            }
            .noTopScrollBlur()
            .statusBarStrip()
            .frame(maxWidth: .infinity)
        }
    }
}

struct Rail: View {
    var body: some View {
        VStack(spacing: 10) {
            LogButton(size: 60).padding(.bottom, 6)
            TabButton(tab: .dex)
            TabButton(tab: .events)
            TabButton(tab: .logbook)
            TabButton(tab: .profile)
            Spacer(minLength: 0)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .padding(.top, 14)
        .frame(width: 84)
        .background {
            Palette.paper
                .overlay(alignment: .trailing) { Rectangle().fill(Palette.ink).frame(width: 3) }
                .ignoresSafeArea(edges: [.top, .bottom, .leading])
        }
    }
}

// MARK: Buttons

struct TabButton: View {
    @Environment(AppModel.self) private var model
    var tab: AppTab

    var body: some View {
        let on = model.tab == tab
        Button {
            if model.tab == tab, tab == .dex { model.dexPath.removeAll() }
            if model.tab == tab, tab == .events { model.eventsPath.removeAll() }
            model.tab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 22, weight: .heavy))
                    .frame(width: 46, height: 34)
                    .background(Capsule().fill(on ? Palette.sun : .clear))
                    .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: on ? 2.5 : 0))
                Text(tab.title)
                    .font(Fonts.body(12, .black, relativeTo: .caption))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(on ? Palette.ink : Palette.muted)
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab-\(tab.rawValue)")
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The big round orange Log button.
struct LogButton: View {
    @Environment(AppModel.self) private var model
    var size: CGFloat

    var body: some View {
        Button {
            model.startLog()
        } label: {
            VStack(spacing: 0) {
                Image(systemName: "plus").font(.system(size: size * 0.36, weight: .black))
                Text("LOG").font(Fonts.title(size * 0.22))
            }
            .foregroundStyle(.white)
            .frame(width: size, height: size)
        }
        .buttonStyle(RoundPressStyle())
        .accessibilityIdentifier("log-button")
        .accessibilityLabel("Log a catch")
    }
}

struct RoundPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Circle().fill(Palette.orange).overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3.5)))
            .offset(y: configuration.isPressed ? 5 : 0)
            .background(Circle().fill(Palette.ink).offset(y: 5))
            .padding(.bottom, 5)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
