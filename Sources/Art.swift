import SpriteKit
import UIKit

enum PlatformKind { case normal, moving, breaking, spring }

/// Alle Grafiken werden einmal per Code gezeichnet und dann zwischengespeichert.
/// Keine Bilddateien nötig, wenig Speicher, schnelle Darstellung.
enum Art {
    private static var texCache: [String: SKTexture] = [:]
    private static var imgCache: [String: UIImage] = [:]

    static func render(_ size: CGSize, _ draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in draw(ctx.cgContext) }
    }

    static func image(_ key: String, _ make: () -> UIImage) -> UIImage {
        if let i = imgCache[key] { return i }
        let i = make()
        imgCache[key] = i
        return i
    }

    static func texture(_ key: String, _ make: () -> UIImage) -> SKTexture {
        if let t = texCache[key] { return t }
        let t = SKTexture(image: make())
        texCache[key] = t
        return t
    }

    static func starPath(center c: CGPoint, outer: CGFloat, inner: CGFloat, points: Int = 5) -> UIBezierPath {
        let p = UIBezierPath()
        for i in 0..<(points * 2) {
            let r = i % 2 == 0 ? outer : inner
            let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / CGFloat(points)
            let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.close()
        return p
    }

    // MARK: - Partikel & Effekte

    static var dot: SKTexture {
        texture("dot") {
            render(CGSize(width: 24, height: 24)) { ctx in
                let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
                ctx.drawRadialGradient(g, startCenter: CGPoint(x: 12, y: 12), startRadius: 0,
                                       endCenter: CGPoint(x: 12, y: 12), endRadius: 12, options: [])
            }
        }
    }

    static var star: SKTexture {
        texture("star") {
            render(CGSize(width: 24, height: 24)) { _ in
                UIColor.white.setFill()
                starPath(center: CGPoint(x: 12, y: 12), outer: 11, inner: 4.5).fill()
            }
        }
    }

    static var ring: SKTexture {
        texture("ring") {
            render(CGSize(width: 64, height: 64)) { _ in
                let p = UIBezierPath(ovalIn: CGRect(x: 4, y: 4, width: 56, height: 56))
                p.lineWidth = 5
                UIColor.white.setStroke()
                p.stroke()
            }
        }
    }

    static var bolt: SKTexture {
        texture("bolt") {
            render(CGSize(width: 20, height: 34)) { _ in
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 12, y: 0))
                p.addLine(to: CGPoint(x: 2, y: 19))
                p.addLine(to: CGPoint(x: 9, y: 19))
                p.addLine(to: CGPoint(x: 6, y: 34))
                p.addLine(to: CGPoint(x: 18, y: 13))
                p.addLine(to: CGPoint(x: 11, y: 13))
                p.close()
                UIColor.white.setFill()
                p.fill()
            }
        }
    }

    /// Weiß, oben durchsichtig, unten deckend – wird eingefärbt für den Himmel.
    static var vGradient: SKTexture {
        texture("vgrad") {
            render(CGSize(width: 8, height: 256)) { ctx in
                let colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.cgColor] as CFArray
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
                ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 256), options: [])
            }
        }
    }

    static var dashed: SKTexture {
        texture("dashed") {
            render(CGSize(width: 400, height: 4)) { _ in
                UIColor.white.setFill()
                var x: CGFloat = 0
                while x < 400 {
                    UIBezierPath(roundedRect: CGRect(x: x, y: 0, width: 14, height: 4), cornerRadius: 2).fill()
                    x += 24
                }
            }
        }
    }

    static var cloud: SKTexture {
        texture("cloud") {
            render(CGSize(width: 140, height: 64)) { _ in
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: 8, y: 26, width: 124, height: 34)).fill()
                UIBezierPath(ovalIn: CGRect(x: 26, y: 10, width: 52, height: 46)).fill()
                UIBezierPath(ovalIn: CGRect(x: 62, y: 2, width: 54, height: 54)).fill()
            }
        }
    }

    static var spring: SKTexture {
        texture("spring") {
            render(CGSize(width: 26, height: 24)) { _ in
                UIColor(hex: 0x6C7A89).setFill()
                UIBezierPath(roundedRect: CGRect(x: 3, y: 20, width: 20, height: 4), cornerRadius: 2).fill()
                let coil = UIBezierPath()
                coil.move(to: CGPoint(x: 6, y: 20))
                var y: CGFloat = 20
                var right = true
                while y > 7 {
                    y -= 3
                    coil.addLine(to: CGPoint(x: right ? 20 : 6, y: y))
                    right.toggle()
                }
                coil.lineWidth = 2.5
                coil.lineCapStyle = .round
                coil.lineJoinStyle = .round
                UIColor(hex: 0xD5DBE3).setStroke()
                coil.stroke()
                UIColor(hex: 0xFF3B6B).setFill()
                UIBezierPath(roundedRect: CGRect(x: 1, y: 1, width: 24, height: 6), cornerRadius: 3).fill()
                UIColor.white.withAlphaComponent(0.5).setFill()
                UIBezierPath(roundedRect: CGRect(x: 4, y: 2, width: 9, height: 2), cornerRadius: 1).fill()
            }
        }
    }

    static var eyes: SKTexture {
        texture("eyes") { render(CGSize(width: 24, height: 13)) { _ in drawEyes(at: CGPoint(x: 12, y: 6.5)) } }
    }

    static func drawEyes(at c: CGPoint) {
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(x: c.x - 12, y: c.y - 6.5, width: 10, height: 13)).fill()
        UIBezierPath(ovalIn: CGRect(x: c.x + 2, y: c.y - 6.5, width: 10, height: 13)).fill()
        UIColor(hex: 0x1B1B2F).setFill()
        UIBezierPath(ovalIn: CGRect(x: c.x - 7.5, y: c.y - 3, width: 5.5, height: 7.5)).fill()
        UIBezierPath(ovalIn: CGRect(x: c.x + 6.5, y: c.y - 3, width: 5.5, height: 7.5)).fill()
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(x: c.x - 6, y: c.y - 2, width: 2, height: 2)).fill()
        UIBezierPath(ovalIn: CGRect(x: c.x + 8, y: c.y - 2, width: 2, height: 2)).fill()
    }

    // MARK: - Münze & Items

    static var coinImage: UIImage {
        image("coin") {
            render(CGSize(width: 28, height: 28)) { ctx in
                let r = CGRect(x: 1.5, y: 1.5, width: 25, height: 25)
                let p = UIBezierPath(ovalIn: r)
                ctx.saveGState()
                p.addClip()
                let colors = [UIColor(hex: 0xFFF08A).cgColor, UIColor(hex: 0xFFC300).cgColor, UIColor(hex: 0xE89B00).cgColor] as CFArray
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1])!
                ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 28), options: [])
                ctx.restoreGState()
                p.lineWidth = 2
                UIColor(hex: 0xB07400).setStroke()
                p.stroke()
                let inner = UIBezierPath(ovalIn: r.insetBy(dx: 4, dy: 4))
                inner.lineWidth = 1.5
                UIColor(hex: 0xFFF6C2).withAlphaComponent(0.8).setStroke()
                inner.stroke()
                UIColor(hex: 0xFFFBE0).setFill()
                starPath(center: CGPoint(x: 14, y: 14.5), outer: 6.5, inner: 2.8).fill()
            }
        }
    }

    static var coin: SKTexture { texture("coinT") { coinImage } }

    private static func drawBubble() {
        let b = UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: 40, height: 40))
        UIColor.white.withAlphaComponent(0.2).setFill()
        b.fill()
        b.lineWidth = 2
        UIColor.white.withAlphaComponent(0.85).setStroke()
        b.stroke()
        UIColor.white.withAlphaComponent(0.6).setFill()
        UIBezierPath(ovalIn: CGRect(x: 10, y: 7, width: 9, height: 5)).fill()
    }

    static func rocketImage(bubble: Bool) -> UIImage {
        image("rocket\(bubble)") {
            render(CGSize(width: 44, height: 44)) { ctx in
                if bubble { drawBubble() }
                UIColor(hex: 0xFF9F1C).setFill()
                let f = UIBezierPath()
                f.move(to: CGPoint(x: 18, y: 31)); f.addLine(to: CGPoint(x: 22, y: 40)); f.addLine(to: CGPoint(x: 26, y: 31)); f.close()
                f.fill()
                UIColor(hex: 0xE63946).setFill()
                let lf = UIBezierPath()
                lf.move(to: CGPoint(x: 17, y: 21)); lf.addLine(to: CGPoint(x: 11, y: 32)); lf.addLine(to: CGPoint(x: 18, y: 30)); lf.close()
                lf.fill()
                let rf = UIBezierPath()
                rf.move(to: CGPoint(x: 27, y: 21)); rf.addLine(to: CGPoint(x: 33, y: 32)); rf.addLine(to: CGPoint(x: 26, y: 30)); rf.close()
                rf.fill()
                let body = UIBezierPath(ovalIn: CGRect(x: 15.5, y: 6, width: 13, height: 27))
                UIColor.white.setFill()
                body.fill()
                ctx.saveGState()
                body.addClip()
                UIColor(hex: 0xE63946).setFill()
                UIRectFill(CGRect(x: 15, y: 5, width: 14, height: 8))
                ctx.restoreGState()
                body.lineWidth = 1.5
                UIColor(hex: 0x8395A7).setStroke()
                body.stroke()
                let w = UIBezierPath(ovalIn: CGRect(x: 19, y: 15, width: 6, height: 6))
                UIColor(hex: 0x48DBFB).setFill()
                w.fill()
            }
        }
    }

    static var magnetImage: UIImage {
        image("magnet") {
            render(CGSize(width: 44, height: 44)) { _ in
                drawBubble()
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 14, y: 14))
                p.addLine(to: CGPoint(x: 14, y: 23))
                p.addArc(withCenter: CGPoint(x: 22, y: 23), radius: 8, startAngle: .pi, endAngle: 0, clockwise: false)
                p.addLine(to: CGPoint(x: 30, y: 14))
                p.lineWidth = 7
                UIColor(hex: 0xE63946).setStroke()
                p.stroke()
                UIColor(hex: 0xDFE6E9).setFill()
                UIRectFill(CGRect(x: 10.5, y: 10, width: 7, height: 5))
                UIRectFill(CGRect(x: 26.5, y: 10, width: 7, height: 5))
            }
        }
    }

    static var rocketItem: SKTexture { texture("rocketItem") { rocketImage(bubble: true) } }
    static var rocketPack: SKTexture { texture("rocketPack") { rocketImage(bubble: false) } }
    static var magnet: SKTexture { texture("magnetT") { magnetImage } }

    // MARK: - Plattformen (110 x 30, Lauffläche 2 pt unter der Oberkante)

    static func platformImage(_ kind: PlatformKind) -> UIImage {
        image("plat\(kind)") {
            render(CGSize(width: 110, height: 30)) { ctx in
                let bodyC: UIColor, topC: UIColor
                switch kind {
                case .normal: bodyC = UIColor(hex: 0x8D6E63); topC = UIColor(hex: 0x6EDC5F)
                case .spring: bodyC = UIColor(hex: 0x8D6E63); topC = UIColor(hex: 0xFF6FB5)
                case .moving: bodyC = UIColor(hex: 0x3E4C6D); topC = UIColor(hex: 0x4FE3FF)
                case .breaking: bodyC = UIColor(hex: 0xA9835A); topC = UIColor(hex: 0xEAD2A2)
                }
                UIColor.black.withAlphaComponent(0.18).setFill()
                UIBezierPath(roundedRect: CGRect(x: 4, y: 10, width: 102, height: 19), cornerRadius: 9).fill()
                let body = UIBezierPath(roundedRect: CGRect(x: 1, y: 5, width: 108, height: 20), cornerRadius: 10)
                bodyC.setFill()
                body.fill()
                ctx.saveGState()
                body.addClip()
                bodyC.darker(0.28).setFill()
                UIRectFill(CGRect(x: 0, y: 17, width: 110, height: 10))
                if kind == .moving {
                    UIColor(hex: 0xFFD166).setFill()
                    var x: CGFloat = 6
                    while x < 110 {
                        UIBezierPath(ovalIn: CGRect(x: x, y: 15, width: 4, height: 4)).fill()
                        x += 14
                    }
                }
                if kind == .breaking {
                    let c = UIBezierPath()
                    c.move(to: CGPoint(x: 30, y: 8)); c.addLine(to: CGPoint(x: 36, y: 16)); c.addLine(to: CGPoint(x: 32, y: 24))
                    c.move(to: CGPoint(x: 72, y: 8)); c.addLine(to: CGPoint(x: 66, y: 15)); c.addLine(to: CGPoint(x: 74, y: 24))
                    c.move(to: CGPoint(x: 52, y: 12)); c.addLine(to: CGPoint(x: 56, y: 22))
                    c.lineWidth = 2
                    UIColor(hex: 0x4A3220).setStroke()
                    c.stroke()
                }
                ctx.restoreGState()
                let top = UIBezierPath(roundedRect: CGRect(x: 0, y: 2, width: 110, height: 10), cornerRadius: 5)
                topC.setFill()
                top.fill()
                UIColor.white.withAlphaComponent(0.4).setFill()
                UIBezierPath(roundedRect: CGRect(x: 9, y: 3.5, width: 38, height: 3), cornerRadius: 1.5).fill()
                UIBezierPath(roundedRect: CGRect(x: 52, y: 3.5, width: 8, height: 3), cornerRadius: 1.5).fill()
            }
        }
    }

    static func platform(_ kind: PlatformKind) -> SKTexture {
        texture("platT\(kind)") { platformImage(kind) }
    }

    // MARK: - Steuerknöpfe

    static func button(_ symbol: String, radius r: CGFloat) -> SKTexture {
        texture("btn\(symbol)\(r)") {
            render(CGSize(width: r * 2, height: r * 2)) { _ in
                let rect = CGRect(x: 2, y: 2, width: r * 2 - 4, height: r * 2 - 4)
                UIColor.black.withAlphaComponent(0.3).setFill()
                UIBezierPath(ovalIn: rect).fill()
                let o = UIBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 1.5))
                o.lineWidth = 3
                UIColor.white.withAlphaComponent(0.65).setStroke()
                o.stroke()
                let cfg = UIImage.SymbolConfiguration(pointSize: r * 0.72, weight: .black)
                if let img = UIImage(systemName: symbol, withConfiguration: cfg)?
                    .withTintColor(.white, renderingMode: .alwaysOriginal) {
                    let s = img.size
                    img.draw(in: CGRect(x: r - s.width / 2, y: r - s.height / 2, width: s.width, height: s.height))
                }
            }
        }
    }

    // MARK: - Charaktere (64 x 72, Füße 8 pt über der Unterkante)

    static func character(_ s: CharacterSkin) -> SKTexture {
        texture("char_" + s.id) { characterImage(s, eyes: false) }
    }

    static func characterPreview(_ s: CharacterSkin) -> UIImage {
        image("prev_" + s.id) { characterImage(s, eyes: true) }
    }

    static func characterImage(_ s: CharacterSkin, eyes: Bool) -> UIImage {
        render(CGSize(width: 64, height: 72)) { ctx in
            if s.gear == .cape {
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 18, y: 28))
                p.addLine(to: CGPoint(x: 46, y: 28))
                p.addLine(to: CGPoint(x: 56, y: 62))
                p.addQuadCurve(to: CGPoint(x: 8, y: 62), controlPoint: CGPoint(x: 32, y: 71))
                p.close()
                s.accent.darker(0.15).setFill()
                p.fill()
            }
            if s.glow {
                ctx.setShadow(offset: .zero, blur: 9, color: s.accent.withAlphaComponent(0.9).cgColor)
            }
            s.body.darker(0.5).setFill()
            UIBezierPath(roundedRect: CGRect(x: 17, y: 56, width: 12, height: 8), cornerRadius: 4).fill()
            UIBezierPath(roundedRect: CGRect(x: 35, y: 56, width: 12, height: 8), cornerRadius: 4).fill()

            let bodyRect = CGRect(x: 14, y: 20, width: 36, height: 40)
            let bp = UIBezierPath(roundedRect: bodyRect, cornerRadius: 13)
            s.body.setFill()
            bp.fill()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)

            ctx.saveGState()
            bp.addClip()
            s.body.darker(0.2).setFill()
            UIRectFill(CGRect(x: 14, y: 47, width: 36, height: 14))
            UIColor.white.withAlphaComponent(0.28).setFill()
            UIBezierPath(ovalIn: CGRect(x: 18, y: 23, width: 13, height: 7)).fill()
            s.accent.setFill()
            UIRectFill(CGRect(x: 14, y: 45, width: 36, height: 4))
            if s.gear == .headband {
                UIRectFill(CGRect(x: 14, y: 25, width: 36, height: 5))
            }
            ctx.restoreGState()

            bp.lineWidth = 2
            s.body.darker(0.55).setStroke()
            bp.stroke()

            switch s.gear {
            case .headband:
                s.accent.setFill()
                let t = UIBezierPath()
                t.move(to: CGPoint(x: 15, y: 26)); t.addLine(to: CGPoint(x: 5, y: 22)); t.addLine(to: CGPoint(x: 7, y: 29)); t.close()
                t.move(to: CGPoint(x: 15, y: 28)); t.addLine(to: CGPoint(x: 6, y: 34)); t.addLine(to: CGPoint(x: 11, y: 36)); t.close()
                t.fill()
            case .antenna:
                let a = UIBezierPath()
                a.move(to: CGPoint(x: 32, y: 20)); a.addLine(to: CGPoint(x: 32, y: 9))
                a.lineWidth = 2.5
                s.body.darker(0.4).setStroke()
                a.stroke()
                ctx.setShadow(offset: .zero, blur: 6, color: s.accent.cgColor)
                s.accent.setFill()
                UIBezierPath(ovalIn: CGRect(x: 28, y: 3, width: 8, height: 8)).fill()
                ctx.setShadow(offset: .zero, blur: 0, color: nil)
            case .horns:
                UIColor(hex: 0xFFF1E0).setFill()
                let h = UIBezierPath()
                h.move(to: CGPoint(x: 17, y: 25)); h.addQuadCurve(to: CGPoint(x: 15, y: 8), controlPoint: CGPoint(x: 13, y: 16)); h.addLine(to: CGPoint(x: 25, y: 21)); h.close()
                h.move(to: CGPoint(x: 47, y: 25)); h.addQuadCurve(to: CGPoint(x: 49, y: 8), controlPoint: CGPoint(x: 51, y: 16)); h.addLine(to: CGPoint(x: 39, y: 21)); h.close()
                h.fill()
            case .halo:
                ctx.setShadow(offset: .zero, blur: 6, color: s.accent.cgColor)
                let h = UIBezierPath(ovalIn: CGRect(x: 19, y: 5, width: 26, height: 8))
                h.lineWidth = 3
                s.accent.setStroke()
                h.stroke()
                ctx.setShadow(offset: .zero, blur: 0, color: nil)
            case .crown:
                let c = UIBezierPath()
                c.move(to: CGPoint(x: 20, y: 22))
                c.addLine(to: CGPoint(x: 19, y: 8))
                c.addLine(to: CGPoint(x: 26, y: 14))
                c.addLine(to: CGPoint(x: 32, y: 5))
                c.addLine(to: CGPoint(x: 38, y: 14))
                c.addLine(to: CGPoint(x: 45, y: 8))
                c.addLine(to: CGPoint(x: 44, y: 22))
                c.close()
                s.accent.setFill()
                c.fill()
                c.lineWidth = 1.5
                s.accent.darker(0.35).setStroke()
                c.stroke()
                UIColor(hex: 0xFF3B6B).setFill()
                UIBezierPath(ovalIn: CGRect(x: 29.5, y: 13, width: 5, height: 5)).fill()
            case .cape:
                s.accent.setFill()
                UIBezierPath(ovalIn: CGRect(x: 15, y: 26, width: 7, height: 7)).fill()
                UIBezierPath(ovalIn: CGRect(x: 42, y: 26, width: 7, height: 7)).fill()
            case .none:
                break
            }

            if eyes { drawEyes(at: CGPoint(x: 35, y: 34)) }
        }
    }
}
