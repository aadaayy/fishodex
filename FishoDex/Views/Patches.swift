import SwiftUI

/// The patch shapes for badges and titles.
struct PatchShapeView: Shape {
    var shape: PatchShape

    func path(in rect: CGRect) -> Path {
        switch shape {
        case .circle: return Path(ellipseIn: rect)
        case .hexagon: return polygon(in: rect, sides: 6, rotate: 0)
        case .star: return star(in: rect)
        case .shield: return shield(in: rect)
        }
    }

    private func polygon(in rect: CGRect, sides: Int, rotate: Double) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY), r = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<sides {
            let a = Double(i) / Double(sides) * 2 * .pi + rotate
            let pt = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }

    private func star(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.04)
        let outer = min(rect.width, rect.height) / 2 * 1.05, inner = outer * 0.58
        var p = Path()
        for i in 0..<10 {
            let a = Double(i) / 10 * 2 * .pi - .pi / 2
            let r = i.isMultiple(of: 2) ? outer : inner
            let pt = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }

    private func shield(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, x = rect.minX, y = rect.minY
        var p = Path()
        p.move(to: CGPoint(x: x + w * 0.5, y: y))
        p.addQuadCurve(to: CGPoint(x: x + w, y: y + h * 0.14), control: CGPoint(x: x + w * 0.8, y: y + h * 0.12))
        p.addLine(to: CGPoint(x: x + w, y: y + h * 0.48))
        p.addQuadCurve(to: CGPoint(x: x + w * 0.5, y: y + h), control: CGPoint(x: x + w * 0.95, y: y + h * 0.82))
        p.addQuadCurve(to: CGPoint(x: x, y: y + h * 0.48), control: CGPoint(x: x + w * 0.05, y: y + h * 0.82))
        p.addLine(to: CGPoint(x: x, y: y + h * 0.14))
        p.addQuadCurve(to: CGPoint(x: x + w * 0.5, y: y), control: CGPoint(x: x + w * 0.2, y: y + h * 0.12))
        p.closeSubpath()
        return p
    }
}

/// A stitched patch: colored when earned, gray with progress when locked.
struct PatchView: View {
    var shape: PatchShape
    var symbol: String?
    var text: String?
    var earned: Bool
    var color: Color
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            PatchShapeView(shape: shape).fill(Palette.ink).offset(y: 3)
            PatchShapeView(shape: shape).fill(earned ? color : Palette.paperShade)
            PatchShapeView(shape: shape).stroke(Palette.ink, lineWidth: 3)
            PatchShapeView(shape: shape)
                .stroke(earned ? Color.white.opacity(0.75) : Palette.muted.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .padding(6)
            Group {
                if let symbol {
                    Image(systemName: earned ? symbol : "lock.fill")
                        .font(.system(size: size * 0.34, weight: .heavy))
                } else if let text {
                    Text(text).font(Fonts.title(size * 0.3)).minimumScaleFactor(0.5).lineLimit(1)
                        .padding(.horizontal, 8)
                }
            }
            .foregroundStyle(earned ? Palette.ink : Palette.muted)
        }
        .frame(width: size, height: size)
    }
}
