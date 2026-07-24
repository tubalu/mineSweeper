import AppKit
import QuartzCore

/// Non-interactive win celebration built from three particle systems:
///   1. a high fountain burst from bottom-center that gravity pulls back down,
///   2. balloons rising steadily from the bottom edge up and off the top,
///   3. confetti drifting gently down from the top edge.
final class ConfettiOverlay: NSView {
    private var fountain: CAEmitterLayer?
    private var topDrift: CAEmitterLayer?
    private var explosion: CAEmitterLayer?
    private var balloonLayers: [CALayer] = []   // real layers => individually poppable
    private var transients: [CAEmitterLayer] = []
    private var celebrating = false
    private var work: [DispatchWorkItem] = []

    private static let colors: [NSColor] = [
        NSColor(srgbRed: 1.00, green: 0.23, blue: 0.19, alpha: 1), // red
        NSColor(srgbRed: 1.00, green: 0.80, blue: 0.00, alpha: 1), // yellow
        NSColor(srgbRed: 0.20, green: 0.78, blue: 0.35, alpha: 1), // green
        NSColor(srgbRed: 0.20, green: 0.48, blue: 1.00, alpha: 1), // blue
        NSColor(srgbRed: 0.95, green: 0.35, blue: 0.75, alpha: 1), // pink
        NSColor(srgbRed: 1.00, green: 0.55, blue: 0.10, alpha: 1), // orange
        NSColor(srgbRed: 0.55, green: 0.35, blue: 0.95, alpha: 1), // purple
    ]

    // Warm tones for the fireball and muted tones for flung debris, so a loss
    // reads as a bomb blast rather than a shower of party confetti.
    private static let fireColors: [NSColor] = [
        NSColor(srgbRed: 1.00, green: 0.80, blue: 0.20, alpha: 1), // amber
        NSColor(srgbRed: 1.00, green: 0.55, blue: 0.10, alpha: 1), // orange
        NSColor(srgbRed: 1.00, green: 0.25, blue: 0.05, alpha: 1), // red-hot
    ]
    private static let debrisColors: [NSColor] = [
        NSColor(srgbRed: 0.18, green: 0.18, blue: 0.20, alpha: 1), // charred
        NSColor(srgbRed: 0.34, green: 0.33, blue: 0.36, alpha: 1), // ash gray
    ]

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
        guard layer != nil else { return }
        celebrating = true

        // Balloons lead: they rise on their own for a beat...
        spawnBalloons()

        // ...then the confetti joins the party.
        schedule(after: 0.9) { [weak self] in self?.startConfetti() }
        schedule(after: 9.5) { [weak self] in self?.stop() }
    }

    /// Second phase of a win: the confetti fountain and top-down drift, started
    /// after the balloons have had a head start rising.
    private func startConfetti() {
        guard celebrating, let host = layer else { return } // celebration still live?

        let fountain = Self.makeEmitter(cells: Self.colors.map(Self.makeFountainCell))
        let topDrift = Self.makeEmitter(cells: Self.colors.map(Self.makeTopDriftCell))
        host.addSublayer(fountain)
        host.addSublayer(topDrift)
        self.fountain = fountain
        self.topDrift = topDrift
        layoutEmitters()

        stopBirth(fountain, after: 0.8)
        stopBirth(topDrift, after: 3.0)
    }

    /// A one-shot blast radiating out from `point` (in this view's layer space,
    /// bottom-left origin): debris flung in every direction that gravity then
    /// rains down, plus a fast flash of bright sparks. Used when the player
    /// detonates a mine.
    func explode(at point: CGPoint) {
        stop()
        wantsLayer = true
        guard let host = layer else { return }

        let explosion = CAEmitterLayer()
        explosion.emitterShape = .point
        explosion.emitterPosition = point
        explosion.emitterSize = CGSize(width: 6, height: 6)
        explosion.beginTime = CACurrentMediaTime()
        explosion.birthRate = 1
        explosion.emitterCells =
            Self.fireColors.map(Self.makeFireCell)
            + Self.debrisColors.map(Self.makeDebrisCell)
            + [Self.makeSmokeCell(), Self.makeSparkCell()]
        host.addSublayer(explosion)
        self.explosion = explosion

        // Fire one dense pulse, then cut births so it reads as a single blast.
        stopBirth(explosion, after: 0.08)
        schedule(after: 3.2) { [weak self] in self?.stop() }
    }

    func stop() {
        celebrating = false
        work.forEach { $0.cancel() }
        work.removeAll()
        [fountain, topDrift, explosion].forEach { $0?.removeFromSuperlayer() }
        balloonLayers.forEach { $0.removeFromSuperlayer() }
        transients.forEach { $0.removeFromSuperlayer() }
        balloonLayers.removeAll()
        transients.removeAll()
        fountain = nil
        topDrift = nil
        explosion = nil
    }

    override func layout() {
        super.layout()
        layoutEmitters()
    }

    // MARK: - positioning

    /// Fountain fires from bottom-center; drift falls from a line just above the
    /// top edge. (Balloons are layers with their own paths, positioned on spawn.)
    private func layoutEmitters() {
        fountain?.emitterPosition = CGPoint(x: bounds.midX, y: 0)
        fountain?.emitterSize = .zero

        topDrift?.emitterPosition = CGPoint(x: bounds.midX, y: bounds.height + 20)
        topDrift?.emitterSize = CGSize(width: bounds.width, height: 0)
    }

    // MARK: - scheduling

    private func stopBirth(_ emitter: CAEmitterLayer, after seconds: TimeInterval) {
        schedule(after: seconds) { [weak emitter] in emitter?.birthRate = 0 }
    }

    private func schedule(after seconds: TimeInterval, _ block: @escaping () -> Void) {
        let item = DispatchWorkItem(block: block)
        work.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    // MARK: - emitter factories

    private static func makeEmitter(cells: [CAEmitterCell]) -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.beginTime = CACurrentMediaTime()
        emitter.birthRate = 1
        emitter.emitterCells = cells
        return emitter
    }

    /// The original burst, tuned to launch higher and hang longer.
    private static func makeFountainCell(color: NSColor) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = scrapImage(color: color)
        cell.birthRate = 22
        cell.lifetime = 4.6
        cell.lifetimeRange = 0.8
        cell.velocity = 540
        cell.velocityRange = 160
        cell.emissionLongitude = .pi / 2      // up
        cell.emissionRange = .pi / 5          // tight cone => bursts up, not sideways
        cell.yAcceleration = -240             // softer gravity => higher peak
        cell.spin = 5
        cell.spinRange = 8
        cell.scale = 0.55
        cell.scaleRange = 0.35
        cell.alphaSpeed = -0.12
        return cell
    }

    // MARK: - balloons (individually poppable)

    /// Spawn a staggered swarm of balloon *layers* rising from a central band at
    /// the bottom, each along a gently curved path up and off the top. Unlike the
    /// emitter-based confetti, these are real layers, so a click can hit-test and
    /// pop an individual balloon.
    private func spawnBalloons() {
        guard let host = layer else { return }
        let count = 18
        let band = bounds.width * 0.35
        let scaleFactor = window?.backingScaleFactor ?? 2

        for i in 0 ..< count {
            let color = Self.colors[i % Self.colors.count]
            let size = CGFloat.random(in: 0.8 ... 1.15)
            let w = 30 * size, h = 46 * size

            let balloon = CALayer()
            balloon.bounds = CGRect(x: 0, y: 0, width: w, height: h)
            balloon.contents = Self.balloonImage(color: color)
            balloon.contentsScale = scaleFactor
            balloon.setValue(color, forKey: "popColor")   // remembered for the pop puff

            let startX = bounds.midX + CGFloat.random(in: -band / 2 ... band / 2)
            let endX = startX + CGFloat.random(in: -30 ... 30)   // gentle wind drift
            let startY = -h                                      // just below the bottom
            let endY = bounds.height + h                         // off the top
            balloon.position = CGPoint(x: endX, y: endY)         // model rests off-screen
            host.addSublayer(balloon)
            balloonLayers.append(balloon)

            // Curved rise: a soft sideways sway via one quadratic control point.
            let path = CGMutablePath()
            path.move(to: CGPoint(x: startX, y: startY))
            let sway = startX + CGFloat.random(in: -40 ... 40)
            path.addQuadCurve(to: CGPoint(x: endX, y: endY),
                              control: CGPoint(x: sway, y: (startY + endY) / 2))

            let rise = CAKeyframeAnimation(keyPath: "position")
            rise.path = path
            let duration = Double.random(in: 3.0 ... 4.6)        // varied speeds
            let delay = Double(i) * 0.04                         // staggered release
            rise.duration = duration
            rise.beginTime = CACurrentMediaTime() + delay
            rise.fillMode = .forwards
            rise.isRemovedOnCompletion = false
            balloon.add(rise, forKey: "rise")

            schedule(after: delay + duration + 0.1) { [weak self, weak balloon] in
                guard let self, let balloon else { return }
                balloon.removeFromSuperlayer()
                self.balloonLayers.removeAll { $0 === balloon }
            }
        }
    }

    /// If a live balloon covers `point` (this view's coordinate space), pop it
    /// and return true; otherwise return false so the click falls through.
    func popBalloon(at point: CGPoint) -> Bool {
        // Reversed: topmost (last-added) balloon wins an overlap.
        for balloon in balloonLayers.reversed() {
            guard let frame = balloon.presentation()?.frame else { continue }
            guard frame.insetBy(dx: -6, dy: -6).contains(point) else { continue }
            let color = (balloon.value(forKey: "popColor") as? NSColor) ?? .white
            popEffect(at: CGPoint(x: frame.midX, y: frame.midY), color: color)
            balloon.removeFromSuperlayer()
            balloonLayers.removeAll { $0 === balloon }
            return true
        }
        return false
    }

    /// A quick confetti puff where a balloon popped.
    private func popEffect(at point: CGPoint, color: NSColor) {
        guard let host = layer else { return }
        let puff = CAEmitterLayer()
        puff.emitterShape = .point
        puff.emitterPosition = point
        puff.emitterSize = CGSize(width: 4, height: 4)
        puff.beginTime = CACurrentMediaTime()
        puff.birthRate = 1

        let cell = CAEmitterCell()
        cell.contents = Self.scrapImage(color: color)
        cell.birthRate = 320
        cell.lifetime = 0.6
        cell.velocity = 190
        cell.velocityRange = 90
        cell.emissionRange = .pi * 2          // burst outward in all directions
        cell.yAcceleration = -420             // then rain down
        cell.spin = 8
        cell.spinRange = 10
        cell.scale = 0.5
        cell.scaleRange = 0.3
        cell.alphaSpeed = -1.6
        puff.emitterCells = [cell]

        host.addSublayer(puff)
        transients.append(puff)
        schedule(after: 0.04) { [weak puff] in puff?.birthRate = 0 }
        schedule(after: 1.2) { [weak self, weak puff] in
            guard let self, let puff else { return }
            puff.removeFromSuperlayer()
            self.transients.removeAll { $0 === puff }
        }
    }

    /// A gentle sprinkle falling from the top edge down through the board.
    private static func makeTopDriftCell(color: NSColor) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = scrapImage(color: color)
        cell.birthRate = 4
        cell.lifetime = 9.0
        cell.lifetimeRange = 1.5
        cell.velocity = 70
        cell.velocityRange = 30
        cell.emissionLongitude = -.pi / 2     // down
        cell.emissionRange = .pi / 6
        cell.yAcceleration = -60              // gentle downward pull
        cell.spin = 3
        cell.spinRange = 6
        cell.scale = 0.5
        cell.scaleRange = 0.3
        cell.alphaSpeed = -0.06
        return cell
    }

    /// The fireball core: warm glowing puffs that flare outward and burn out.
    private static func makeFireCell(color: NSColor) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = glowImage(color: color)
        cell.birthRate = 140
        cell.lifetime = 0.55
        cell.lifetimeRange = 0.2
        cell.velocity = 320
        cell.velocityRange = 180
        cell.emissionRange = .pi * 2
        cell.yAcceleration = 60               // hot gas lifts a little
        cell.scale = 0.9
        cell.scaleRange = 0.5
        cell.scaleSpeed = 0.8                 // swells as it burns
        cell.alphaSpeed = -2.2                // flare and gone
        return cell
    }

    /// Billowing smoke that lingers after the flash and drifts up.
    private static func makeSmokeCell() -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = smokeImage()
        cell.birthRate = 90
        cell.lifetime = 1.9
        cell.lifetimeRange = 0.6
        cell.velocity = 130
        cell.velocityRange = 80
        cell.emissionRange = .pi * 2
        cell.yAcceleration = 30               // smoke rises
        cell.scale = 0.7
        cell.scaleRange = 0.4
        cell.scaleSpeed = 1.4                 // expands into a cloud
        cell.spin = 0.6
        cell.spinRange = 1.2
        cell.alphaSpeed = -0.7
        return cell
    }

    /// Charred scraps hurled outward in all directions, then dragged down.
    private static func makeDebrisCell(color: NSColor) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = scrapImage(color: color)
        cell.birthRate = 200
        cell.lifetime = 2.6
        cell.lifetimeRange = 0.8
        cell.velocity = 430
        cell.velocityRange = 230
        cell.emissionRange = .pi * 2          // radiate in every direction
        cell.yAcceleration = -520             // blast out, then gravity rains it down
        cell.spin = 6
        cell.spinRange = 10
        cell.scale = 0.7
        cell.scaleRange = 0.5
        cell.alphaSpeed = -0.35
        return cell
    }

    /// A quick flash of bright sparks at the blast core.
    private static func makeSparkCell() -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = sparkImage()
        cell.birthRate = 600
        cell.lifetime = 0.7
        cell.lifetimeRange = 0.3
        cell.velocity = 560
        cell.velocityRange = 280
        cell.emissionRange = .pi * 2
        cell.yAcceleration = -220
        cell.scale = 0.6
        cell.scaleRange = 0.4
        cell.alphaSpeed = -1.4                // flare and vanish
        return cell
    }

    // MARK: - particle images

    private static func scrapImage(color: NSColor) -> CGImage {
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

    private static func sparkImage() -> CGImage {
        let size = NSSize(width: 8, height: 8)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor(srgbRed: 1, green: 0.95, blue: 0.6, alpha: 1).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        var rect = NSRect(origin: .zero, size: size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
    }

    /// A soft radial disc, bright core fading to transparent — for fire glow.
    private static func glowImage(color: NSColor) -> CGImage {
        radialImage([NSColor(srgbRed: 1, green: 0.95, blue: 0.75, alpha: 1),
                     color.withAlphaComponent(0.85),
                     color.withAlphaComponent(0)],
                    locations: [0, 0.45, 1], size: 24)
    }

    /// A soft gray radial disc fading to transparent — for smoke puffs.
    private static func smokeImage() -> CGImage {
        radialImage([NSColor(white: 0.55, alpha: 0.85),
                     NSColor(white: 0.40, alpha: 0)],
                    locations: [0, 1], size: 26)
    }

    private static func radialImage(_ colors: [NSColor], locations: [CGFloat],
                                    size: CGFloat) -> CGImage {
        let dims = NSSize(width: size, height: size)
        let image = NSImage(size: dims, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            NSGradient(colors: colors, atLocations: locations, colorSpace: .sRGB)?
                .draw(fromCenter: center, radius: 0,
                      toCenter: center, radius: rect.width / 2, options: [])
            return true
        }
        var rect = NSRect(origin: .zero, size: dims)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
    }

    private static func balloonImage(color: NSColor) -> CGImage {
        let size = NSSize(width: 30, height: 46)
        let image = NSImage(size: size, flipped: false) { _ in
            // Body: an egg-shaped ellipse in the upper portion.
            let body = NSRect(x: 3, y: 16, width: 24, height: 28)
            color.setFill()
            NSBezierPath(ovalIn: body).fill()

            // Knot: a little triangle tucked under the body.
            let knot = NSBezierPath()
            knot.move(to: NSPoint(x: 15, y: 16))
            knot.line(to: NSPoint(x: 11, y: 11))
            knot.line(to: NSPoint(x: 19, y: 11))
            knot.close()
            knot.fill()

            // String: a softly curved line hanging to the bottom edge.
            let string = NSBezierPath()
            string.move(to: NSPoint(x: 15, y: 11))
            string.curve(to: NSPoint(x: 15, y: 0),
                         controlPoint1: NSPoint(x: 22, y: 8),
                         controlPoint2: NSPoint(x: 9, y: 4))
            NSColor(white: 0.35, alpha: 0.7).setStroke()
            string.lineWidth = 1
            string.stroke()

            // Highlight: a soft shine near the top-left for a glossy look.
            let shine = NSRect(x: 8, y: 32, width: 7, height: 9)
            NSColor(white: 1, alpha: 0.5).setFill()
            NSBezierPath(ovalIn: shine).fill()
            return true
        }
        var rect = NSRect(origin: .zero, size: size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
    }
}
