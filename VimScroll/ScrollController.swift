import AppKit
import ApplicationServices
import CoreGraphics

final class ScrollController {
    private static let triggerKeyCode: CGKeyCode = 57 // Caps Lock

    var isEnabled = true {
        didSet {
            if !isEnabled {
                stopScrolling()
                onTriggerKeyChanged?(false)
            } else if triggerKeyIsDown {
                onTriggerKeyChanged?(true)
            }
            onStateChanged?()
        }
    }

    var speed: ScrollSpeed {
        didSet {
            UserDefaults.standard.set(speed.rawValue, forKey: Self.speedDefaultsKey)
            onStateChanged?()
        }
    }

    var onStateChanged: (() -> Void)?
    var onTriggerKeyChanged: ((Bool) -> Void)?

    private static let speedDefaultsKey = "scrollSpeed"
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var scrollTimer: DispatchSourceTimer?
    private var heldDirections = Set<ScrollDirection>()
    private var triggerKeyIsDown = false

    init() {
        let savedSpeed = UserDefaults.standard.integer(forKey: Self.speedDefaultsKey)
        speed = ScrollSpeed(rawValue: savedSpeed) ?? .normal
    }

    deinit {
        stop()
    }

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    var isListening: Bool {
        eventTap != nil
    }

    @discardableResult
    func requestAccessibilityPermission(showPrompt: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: showPrompt
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }
        guard hasAccessibilityPermission else {
            onStateChanged?()
            return false
        }

        let mask = (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
            | (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: vimScrollEventCallback,
            userInfo: context
        ) else {
            onStateChanged?()
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        onStateChanged?()
        return true
    }

    func stop() {
        stopScrolling()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }
        runLoopSource = nil
        eventTap = nil
        triggerKeyIsDown = false
        onTriggerKeyChanged?(false)
        onStateChanged?()
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        if keyCode == Self.triggerKeyCode,
           type == .flagsChanged || type == .keyDown || type == .keyUp {
            guard isEnabled else {
                triggerKeyIsDown = false
                onTriggerKeyChanged?(false)
                return Unmanaged.passUnretained(event)
            }

            // Caps Lock's modifier flag is a latched toggle, so use the physical
            // HID key state to turn it into a momentary press-and-hold trigger.
            let newValue: Bool
            switch type {
            case .keyDown:
                newValue = true
            case .keyUp:
                newValue = false
            default:
                newValue = CGEventSource.keyState(.hidSystemState, key: Self.triggerKeyCode)
            }
            if newValue != triggerKeyIsDown {
                triggerKeyIsDown = newValue
                onTriggerKeyChanged?(triggerKeyIsDown)
            }
            if !triggerKeyIsDown { stopScrolling() }

            // While enabled, Caps Lock is reserved for VimScroll and no longer
            // toggles capitalization.
            return nil
        }

        guard isEnabled, triggerKeyIsDown,
              let direction = ScrollDirection.from(keyCode: keyCode) else {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .keyDown:
            let wasInserted = heldDirections.insert(direction).inserted
            if wasInserted {
                postScrollEvent()
                startScrollTimerIfNeeded()
            }
            return nil
        case .keyUp:
            heldDirections.remove(direction)
            if heldDirections.isEmpty { stopScrollTimer() }
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func startScrollTimerIfNeeded() {
        guard scrollTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(16), repeating: .milliseconds(16), leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in self?.postScrollEvent() }
        scrollTimer = timer
        timer.resume()
    }

    private func stopScrollTimer() {
        scrollTimer?.setEventHandler {}
        scrollTimer?.cancel()
        scrollTimer = nil
    }

    private func stopScrolling() {
        heldDirections.removeAll()
        stopScrollTimer()
    }

    private func postScrollEvent() {
        guard !heldDirections.isEmpty else { return }
        var horizontal: Int32 = 0
        var vertical: Int32 = 0
        for direction in heldDirections {
            let vector = direction.vector
            horizontal += vector.horizontal
            vertical += vector.vertical
        }

        let amount = Int32(speed.rawValue)
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: vertical * amount,
            wheel2: horizontal * amount,
            wheel3: 0
        ) else { return }
        // Scroll-wheel events are routed by location. Refresh it for every frame so
        // moving the pointer while a key is held immediately changes the target area.
        if let pointerEvent = CGEvent(source: nil) {
            event.location = pointerEvent.location
        }
        event.post(tap: .cghidEventTap)
    }
}

private func vimScrollEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<ScrollController>.fromOpaque(userInfo).takeUnretainedValue()
    return controller.handle(type: type, event: event)
}
