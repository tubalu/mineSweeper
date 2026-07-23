import AppKit
import QuartzCore

/// Non-interactive particle overlay. Fountain burst from bottom-center up,
/// then gravity pulls scraps down when the player wins.
final class ConfettiOverlay: NSView {
    private var emitter: CAEmitterLayer?
    private var stopWork: DispatchWorkItem?
    private var removeWork: DispatchWorkItem?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Pass clicks through to the board underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func burst() {
        stop()
        wantsLayer = true
        guard let host = layer else { return }

        let emitter = CAEmitterLayer()
        // Layer coords: +y is up — shoot from bottom center.
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: 0)
        emitter.emitterSize = .zero
        emitter.emitterShape = .point
        emitter.beginTime = CACurrentMediaTime()
        emitter.birthRate = 1

        let colors: [NSColor] = [
            NSColor(srgbRed: 1.00, green: 0.23, blue: 0.19, alpha: 1), // red
            NSColor(srgbRed: 1.00, green: 0.80, blue: 0.00, alpha: 1), // yellow
            NSColor(srgbRed: 0.20, green: 0.78, blue: 0.35, alpha: 1), // green
            NSColor(srgbRed: 0.20, green: 0.48, blue: 1.00, alpha: 1), // blue
            NSColor(srgbRed: 0.95, green: 0.35, blue: 0.75, alpha: 1), // pink
            NSColor(srgbRed: 1.00, green: 0.55, blue: 0.10, alpha: 1), // orange
            NSColor(srgbRed: 0.55, green: 0.35, blue: 0.95, alpha: 1), // purple
        ]

        emitter.emitterCells = colors.map { Self.makeCell(color: $0) }
        host.addSublayer(emitter)
        self.emitter = emitter

        let stop = DispatchWorkItem { [weak self] in
            self?.emitter?.birthRate = 0
        }
        stopWork = stop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: stop)

        let remove = DispatchWorkItem { [weak self] in
            self?.stop()
        }
        removeWork = remove
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: remove)
    }

    func stop() {
        stopWork?.cancel()
        removeWork?.cancel()
        stopWork = nil
        removeWork = nil
        emitter?.removeFromSuperlayer()
        emitter = nil
    }

    override func layout() {
        super.layout()
        if let emitter {
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: 0)
            emitter.emitterSize = .zero
        }
    }

    private static func makeCell(color: NSColor) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = particleImage(color: color)
        cell.birthRate = 22
        cell.lifetime = 4.2
        cell.lifetimeRange = 0.8
        cell.velocity = 380
        cell.velocityRange = 140
        // Layer coords: +y is up. Spray upward, then gravity pulls down.
        cell.emissionLongitude = .pi / 2
        cell.emissionRange = .pi / 2.4
        cell.yAcceleration = -320
        cell.spin = 5
        cell.spinRange = 8
        cell.scale = 0.55
        cell.scaleRange = 0.35
        cell.alphaSpeed = -0.12
        return cell
    }

    private static func particleImage(color: NSColor) -> CGImage {
        let size = NSSize(width: 10, height: 5)
        let image = NSImage(size: size, flipped: false) { rect in
            color.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
                         xRadius: 1, yRadius: 1).fill()
            return true
        }
        var rect = NSRect(origin: .zero, size: size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
    }
}
