import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let scrollController = ScrollController()
    private let cursorIndicator = CursorIndicatorController()
    private var statusItem: NSStatusItem!
    private var retryTimer: Timer?

    private lazy var statusMenu: NSMenu = {
        let menu = NSMenu()
        menu.delegate = self

        let status = NSMenuItem(title: "状态：正在检查…", action: nil, keyEquivalent: "")
        status.isEnabled = false
        status.tag = MenuTag.status.rawValue
        menu.addItem(status)

        let hint = NSMenuItem(title: "Caps Lock + H/J/K/L · 鼠标所在区域", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "启用 VimScroll", action: #selector(toggleEnabled(_:)), keyEquivalent: "")
        toggle.target = self
        toggle.tag = MenuTag.toggle.rawValue
        menu.addItem(toggle)

        let speedItem = NSMenuItem(title: "滚动速度", action: nil, keyEquivalent: "")
        let speedMenu = NSMenu()
        for speed in ScrollSpeed.allCases {
            let item = NSMenuItem(title: speed.title, action: #selector(selectSpeed(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = speed.rawValue
            item.tag = MenuTag.speed.rawValue
            speedMenu.addItem(item)
        }
        speedItem.submenu = speedMenu
        menu.addItem(speedItem)

        menu.addItem(.separator())
        let permission = NSMenuItem(title: "辅助功能权限…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permission.target = self
        permission.tag = MenuTag.permission.rawValue
        menu.addItem(permission)

        let about = NSMenuItem(title: "关于 VimScroll", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 VimScroll", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "arrow.up.and.down.and.arrow.left.and.right",
                accessibilityDescription: "VimScroll"
            )
            button.toolTip = "VimScroll — Caps Lock + H/J/K/L"
        }
        statusItem.menu = statusMenu

        scrollController.onStateChanged = { [weak self] in
            DispatchQueue.main.async { self?.updateMenu() }
        }
        scrollController.onTriggerKeyChanged = { [weak self] isDown in
            DispatchQueue.main.async {
                if isDown {
                    self?.cursorIndicator.show()
                } else {
                    self?.cursorIndicator.hide()
                }
            }
        }

        if scrollController.hasAccessibilityPermission {
            scrollController.start()
        } else {
            _ = scrollController.requestAccessibilityPermission(showPrompt: true)
            startPermissionRetryTimer()
        }
        updateMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        retryTimer?.invalidate()
        cursorIndicator.hide()
        scrollController.stop()
    }

    func menuWillOpen(_ menu: NSMenu) {
        if scrollController.hasAccessibilityPermission {
            _ = scrollController.start()
        }
        updateMenu()
    }

    private func updateMenu() {
        let permissionGranted = scrollController.hasAccessibilityPermission
        let statusText: String
        if !permissionGranted {
            statusText = "状态：需要辅助功能权限"
        } else if scrollController.isListening {
            statusText = "状态：监听中"
        } else {
            statusText = "状态：监听未启动"
        }
        statusMenu.items.first(where: { $0.tag == MenuTag.status.rawValue })?.title = statusText
        statusMenu.items.first(where: { $0.tag == MenuTag.toggle.rawValue })?.state = scrollController.isEnabled ? .on : .off
        statusMenu.items.first(where: { $0.tag == MenuTag.permission.rawValue })?.title = permissionGranted
            ? "辅助功能权限：已授权"
            : "授予辅助功能权限…"

        if let button = statusItem?.button {
            button.appearsDisabled = !scrollController.isEnabled || !permissionGranted
        }

        for item in statusMenu.items.compactMap(\.submenu).flatMap(\.items) where item.tag == MenuTag.speed.rawValue {
            item.state = (item.representedObject as? Int) == scrollController.speed.rawValue ? .on : .off
        }
    }

    private func startPermissionRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            guard let self else { return }
            if self.scrollController.hasAccessibilityPermission {
                timer.invalidate()
                self.retryTimer = nil
                _ = self.scrollController.start()
                self.updateMenu()
            }
        }
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        scrollController.isEnabled.toggle()
    }

    @objc private func selectSpeed(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? Int,
              let speed = ScrollSpeed(rawValue: rawValue) else { return }
        scrollController.speed = speed
    }

    @objc private func openAccessibilitySettings() {
        _ = scrollController.requestAccessibilityPermission(showPrompt: true)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startPermissionRetryTimer()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "VimScroll"
        alert.informativeText = "按住 Caps Lock 时，鼠标旁会出现蓝色方向环；再按 H/J/K/L，即可像 Vim 一样向左/下/上/右滚动鼠标所在区域。暂停 VimScroll 后，Caps Lock 恢复正常。\n\n版本 1.2.0"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private enum MenuTag: Int {
    case status = 50
    case toggle = 100
    case speed = 200
    case permission = 300
}
