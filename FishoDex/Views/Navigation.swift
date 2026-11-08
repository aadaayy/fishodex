import SwiftUI
import UIKit

/// The round back button, a cream sticker with a navy outline, the same on
/// fish pages, catches and Log a catch.
struct BackButton: View {
    var identifier = "page-back"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left").font(.system(size: 16, weight: .black))
                .foregroundStyle(Palette.ink)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Palette.paper))
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2.5))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
        .accessibilityIdentifier(identifier)
    }
}

/// A pushed page's top: back and the page's name on a solid strip of water,
/// drawn by the app (not the system bar) so nothing shows through it when the
/// page scrolls, and it looks the same on every phone.
struct PageHeader: ViewModifier {
    var title: String
    @Environment(\.isPresented) private var pushed
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                ZStack {
                    Text(title)
                        .font(Fonts.title(22, relativeTo: .title3))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 56)
                        .accessibilityAddTraits(.isHeader)
                    HStack {
                        if pushed { BackButton { dismiss() } }
                        Spacer()
                    }
                }
                .frame(minHeight: 44)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity)
                .background {
                    Palette.water
                        .overlay(alignment: .bottom) { Rectangle().fill(Palette.waterDeep).frame(height: 2) }
                        .ignoresSafeArea(edges: .top)
                }
            }
    }
}

extension View {
    func pageHeader(_ title: String) -> some View { modifier(PageHeader(title: title)) }

    /// A solid strip of water behind the status bar, so lists scrolling up
    /// don't show through the time and battery.
    func statusBarStrip() -> some View {
        overlay(alignment: .top) {
            Color.clear.frame(height: 0)
                .background(Palette.water.ignoresSafeArea(edges: .top))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// No soft blur at the top of scrolling screens (iOS 26 and later): the
    /// app draws its own solid strip there instead.
    @ViewBuilder
    func noTopScrollBlur() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectHidden(true, for: .top)
        } else {
            self
        }
    }
}

/// Hiding the system bar also turns off swiping from the left edge to go
/// back; this keeps the swipe on any pushed page.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
