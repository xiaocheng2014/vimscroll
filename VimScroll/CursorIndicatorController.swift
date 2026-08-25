import AppKit

/// A click-through halo that makes the global Caps Lock trigger state visible without
/// replacing the user's chosen system cursor.
final class CursorIndicatorController {
    private let size = NSSize(width: 50, height: 50)
    private var trackingTimer: Timer?
    private var isVisible = false

    private lazy var panel: NSPanel = {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = CursorHaloView(frame: NSRect(origin: .zero, size: size))
        return panel
    }()

    func show() {
        guard !isVisible else { return }
        isVisible = true
        updatePosition()
        panel.orderFrontRegardless()

        trackingTimer?.invalidate()
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updatePosition()
        }
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        trackingTimer?.invalidate()
        trackingTimer = nil
        panel.orderOut(nil)
    }

    private func updatePosition() {
        let pointer = NSEvent.mouseLocation
        panel.setFrameOrigin(NSPoint(x: pointer.x - size.width / 2, y: pointer.y - size.height / 2))
    }
}

private final class CursorHaloView: NSView {
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let outerRect = bounds.insetBy(dx: 5, dy: 5)
        let glow = NSBezierPath(ovalIn: outerRect)
        NSColor.systemBlue.withAlphaComponent(0.16).setFill()
        glow.fill()
        NSColor.systemBlue.withAlphaComponent(0.95).setStroke()
        glow.lineWidth = 3
        glow.stroke()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.systemBlue
        ]
        let marker = "⇪"
        let markerSize = marker.size(withAttributes: attributes)
        marker.draw(
            at: NSPoint(
                x: bounds.midX - markerSize.width / 2,
                y: bounds.midY - markerSize.height / 2
            ),
            withAttributes: attributes
        )
    }
}
