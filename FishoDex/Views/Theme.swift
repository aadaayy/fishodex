import SwiftUI

/// The tackle-shop sticker look: cream panels, thick navy outlines, a solid
/// drop edge, bright flats water, orange main buttons and sunny highlights.
enum Palette {
    static let ink = Color(hex: 0x16213E)
    static let paper = Color(hex: 0xFFFCF4)
    static let paperShade = Color(hex: 0xF3EEDF)
    static let sun = Color(hex: 0xFFC72C)
    static let orange = Color(hex: 0xFF6B2C)
    static let water = Color(hex: 0x2FA9BC)
    static let waterLight = Color(hex: 0x5CC3D0)
    static let waterDeep = Color(hex: 0x1E8C9E)
    static let night = Color(hex: 0x203063)
    static let night2 = Color(hex: 0x2A3C78)
    static let muted = Color(hex: 0x5B6478)
    static let good = Color(hex: 0x3CC48E)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension Rarity {
    var color: Color {
        switch self {
        case .common: return Color(hex: 0xB8C2CC)
        case .uncommon: return Color(hex: 0x3CC48E)
        case .rare: return Color(hex: 0x3B8BEB)
        case .trophy: return Color(hex: 0xFF6B2C)
        case .legendary: return Color(hex: 0xFFC72C)
        }
    }
}

extension Habitat {
    var color: Color {
        switch self {
        case .freshwater: return Color(hex: 0x6CC04A)
        case .inshore: return Color(hex: 0xF2A541)
        case .offshore: return Color(hex: 0x3563D6)
        }
    }

    var symbol: String {
        switch self {
        case .freshwater: return "leaf.fill"
        case .inshore: return "water.waves"
        case .offshore: return "sailboat.fill"
        }
    }
}

/// Lilita One for titles, Nunito for everything else. Both scale with the
/// phone's text size setting.
enum Fonts {
    static func title(_ size: CGFloat, relativeTo style: Font.TextStyle = .title2) -> Font {
        .custom("LilitaOne", size: size, relativeTo: style)
    }

    static func body(_ size: CGFloat, _ weight: Weight = .bold, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.fontName, size: size, relativeTo: style)
    }

    enum Weight {
        case regular, bold, extraBold, black
        var fontName: String {
            switch self {
            case .regular: return "Nunito-Regular"
            case .bold: return "Nunito-Bold"
            case .extraBold: return "Nunito-ExtraBold"
            case .black: return "Nunito-Black"
            }
        }
    }
}

/// A cream panel with a thick outline and a solid edge underneath.
struct StickerBackground: ViewModifier {
    var fill: Color = Palette.paper
    var radius: CGFloat = 18
    var lift: CGFloat = 5
    var line: CGFloat = 3

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Palette.ink, lineWidth: line)
                    }
            }
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.ink)
                    .offset(y: lift)
            }
            .padding(.bottom, lift)
    }
}

extension View {
    func sticker(_ fill: Color = Palette.paper, radius: CGFloat = 18, lift: CGFloat = 5, line: CGFloat = 3) -> some View {
        modifier(StickerBackground(fill: fill, radius: radius, lift: lift, line: line))
    }
}

/// A chunky button that presses down into its edge when tapped.
struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = Palette.orange
    var text: Color = .white
    var radius: CGFloat = 16
    var size: CGFloat = 19
    var lift: CGFloat = 5
    var expand = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(Fonts.title(size, relativeTo: .headline))
            .foregroundStyle(text)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: expand ? .infinity : nil)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Palette.ink, lineWidth: 3)
                    }
            }
            .offset(y: pressed ? lift : 0)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.ink)
                    .offset(y: lift)
            }
            .padding(.bottom, lift)
            .animation(.easeOut(duration: 0.08), value: pressed)
            .contentShape(Rectangle())
    }
}

/// A small rounded label, like "COMMON" or "NEW".
struct Pill: View {
    var text: String
    var fill: Color = Palette.sun
    var textColor: Color = Palette.ink
    var size: CGFloat = 12

    var body: some View {
        Text(text.uppercased())
            .font(Fonts.body(size, .black, relativeTo: .caption))
            .kerning(0.6)
            .foregroundStyle(textColor)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5))
    }
}

/// Bright turquoise flats water with soft wave lines.
struct WaterBackground: View {
    var deep = false

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(deep ? Palette.night : Palette.water))
            let line = (deep ? Palette.night2 : Palette.waterLight).opacity(0.7)
            var y: CGFloat = 40
            var row = 0
            while y < size.height + 40 {
                var path = Path()
                let shift: CGFloat = row.isMultiple(of: 2) ? 0 : 45
                var x: CGFloat = -90 + shift
                while x < size.width + 90 {
                    path.move(to: CGPoint(x: x, y: y))
                    path.addQuadCurve(to: CGPoint(x: x + 30, y: y), control: CGPoint(x: x + 15, y: y - 7))
                    x += 90
                }
                context.stroke(path, with: .color(line), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                y += 54
                row += 1
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// An XP bar: a rounded track that fills with sun yellow.
struct XPBar: View {
    var fraction: Double
    var height: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.paperShade)
                Capsule().fill(Palette.sun)
                    .frame(width: max(height, geo.size.width * min(max(fraction, 0), 1)))
                    .opacity(fraction <= 0 ? 0 : 1)
                Capsule().strokeBorder(Palette.ink, lineWidth: 2.5)
            }
        }
        .frame(height: height)
    }
}

/// A completion ring, like 7 of 23.
struct Ring: View {
    var fraction: Double
    var color: Color
    var line: CGFloat = 7

    var body: some View {
        ZStack {
            Circle().stroke(Palette.paperShade, lineWidth: line)
            Circle().trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle().stroke(Palette.ink, lineWidth: 2).padding(-line / 2)
            Circle().stroke(Palette.ink, lineWidth: 2).padding(line / 2)
        }
    }
}

/// A field that looks like a sticker: paper fill, ink outline.
struct StickerField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Fonts.body(17, .bold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2.5))
    }
}

extension View {
    func stickerField() -> some View { modifier(StickerField()) }
}

/// A section title on a panel, like "FUN FACT".
struct PanelTitle: View {
    var text: String
    var symbol: String?

    var body: some View {
        HStack(spacing: 6) {
            if let symbol { Image(systemName: symbol).font(.system(size: 15, weight: .heavy)) }
            Text(text).font(Fonts.title(20, relativeTo: .headline))
        }
        .foregroundStyle(Palette.ink)
        .accessibilityAddTraits(.isHeader)
    }
}
