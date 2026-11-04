import AppKit

/// Barkeeper's own menu bar glyphs, drawn as template images (SF Symbols has no bee).
enum CustomIcons {
    static let prefix = "custom."
    static let names = ["custom.bee", "custom.beebot"]

    static func image(_ name: String) -> NSImage? {
        let draw: ((NSRect) -> Void)? = switch name {
        case "custom.bee": drawBee
        case "custom.beebot": drawBeeBot
        default: nil
        }
        guard let draw else { return nil }
        let image = NSImage(size: NSSize(width: 18, height: 16), flipped: true) { rect in
            NSColor.black.set()
            draw(rect)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Barkeeper"
        return image
    }

    /// Side view: striped body with a stinger, two wings above it, head with antennae.
    private static func drawBee(_ r: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // Body with a stinger, stripes cut out.
        let body = NSBezierPath(ovalIn: NSRect(x: 4.6, y: 7, width: 10.8, height: 7.6))
        body.fill()
        let stinger = NSBezierPath()
        stinger.move(to: NSPoint(x: 15, y: 9.9))
        stinger.line(to: NSPoint(x: 17.6, y: 10.8))
        stinger.line(to: NSPoint(x: 15, y: 11.7))
        stinger.close()
        stinger.fill()
        ctx.saveGState()
        body.addClip()
        ctx.setBlendMode(.clear)
        for x in [8.4, 11.5] { ctx.fill(CGRect(x: x, y: 6, width: 1.3, height: 10)) }
        ctx.restoreGState()
        // Head, separated from the body by a thin gap.
        let head = NSBezierPath(ovalIn: NSRect(x: 0.9, y: 7.6, width: 5, height: 5))
        ctx.saveGState()
        ctx.setBlendMode(.clear)
        head.lineWidth = 2
        head.stroke()
        ctx.restoreGState()
        head.fill()
        // Wings above the body.
        let wings = NSBezierPath()
        wings.appendOval(in: NSRect(x: 6.4, y: 1.4, width: 4, height: 5.2))
        wings.appendOval(in: NSRect(x: 9.8, y: 2.4, width: 3.6, height: 4.4))
        wings.lineWidth = 1.1
        wings.stroke()
        // Antennae.
        let antennae = NSBezierPath()
        antennae.move(to: NSPoint(x: 2.4, y: 8)); antennae.line(to: NSPoint(x: 1.2, y: 4.6))
        antennae.move(to: NSPoint(x: 4.4, y: 7.8)); antennae.line(to: NSPoint(x: 4.8, y: 4.4))
        antennae.lineWidth = 0.9
        antennae.lineCapStyle = .round
        antennae.stroke()
    }

    /// Front view of a round robot bee head: visor with smiling eyes and two antennae.
    private static func drawBeeBot(_ r: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let antennae = NSBezierPath()
        antennae.move(to: NSPoint(x: 6.6, y: 5.2)); antennae.line(to: NSPoint(x: 5, y: 2))
        antennae.move(to: NSPoint(x: 11.4, y: 5.2)); antennae.line(to: NSPoint(x: 13, y: 2))
        antennae.lineWidth = 1.2
        antennae.lineCapStyle = .round
        antennae.stroke()
        NSBezierPath(ovalIn: NSRect(x: 3.5, y: 0.2, width: 3, height: 3)).fill()
        NSBezierPath(ovalIn: NSRect(x: 11.5, y: 0.2, width: 3, height: 3)).fill()
        // Head.
        NSBezierPath(ovalIn: NSRect(x: 2.5, y: 3.8, width: 13, height: 11.8)).fill()
        // Visor cut out, eyes left solid inside it.
        ctx.saveGState()
        ctx.setBlendMode(.clear)
        NSBezierPath(roundedRect: NSRect(x: 4.6, y: 7, width: 8.8, height: 5.8), xRadius: 2.6, yRadius: 2.6).fill()
        ctx.restoreGState()
        for x in [6.3, 9.9] {
            let eye = NSBezierPath()
            eye.appendArc(withCenter: NSPoint(x: x + 0.9, y: 10.6), radius: 1.3, startAngle: 200, endAngle: 340)
            eye.lineWidth = 1.1
            eye.lineCapStyle = .round
            eye.stroke()
        }
    }
}
