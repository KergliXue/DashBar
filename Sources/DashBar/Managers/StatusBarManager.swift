import AppKit

/// One instance per plugin. Manages the NSStatusItem + right-click context menu.
@MainActor
final class PluginStatusItem {

    var onLeftClick: (() -> Void)?
    var onDisable: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    let descriptor: ScriptDescriptor
    private let statusItem: NSStatusItem

    init(descriptor: ScriptDescriptor) {
        self.descriptor = descriptor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        applyAppearance()
        configureClicks()
        registerScrollWheel()
    }

    // MARK: - Appearance

    private func applyAppearance() {
        guard let button = statusItem.button else { return }

        let icon = resolveIcon()
        button.image = icon
        button.imagePosition = .imageLeft
        button.imageScaling = .scaleProportionallyDown

        if descriptor.showText {
            button.title = descriptor.name
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        } else {
            button.title = ""
        }
    }

    private func resolveIcon() -> NSImage? {
        if let sfName = descriptor.sfSymbol,
           let symbol = NSImage(systemSymbolName: sfName, accessibilityDescription: descriptor.name) {
            let configured = symbol.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            )
            configured?.isTemplate = true
            return configured
        }
        if let iconFile = descriptor.iconPath {
            let url = descriptor.pluginDir.appendingPathComponent(iconFile)
            if let img = NSImage(contentsOf: url) {
                img.isTemplate = true
                img.size = NSSize(width: 18, height: 18)
                return img
            }
        }
        return Self.makeDefaultIcon()
    }

    private var lastScrollText: String = ""

    func updateButtonText(_ text: String) {
        guard descriptor.showText, let button = statusItem.button else { return }
        let firstLine = text.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces) ?? ""
        let trimmed = String(firstLine.prefix(40))
        button.title = trimmed
        lastScrollText = text
    }

    // MARK: - Scroll wheel

    private func registerScrollWheel() {
        guard statusItem.button != nil else { return }
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self,
                  let button = self.statusItem.button,
                  event.window === button.window,
                  self.descriptor.showText
            else { return event }

            let allLines = self.lastScrollText.components(separatedBy: .newlines)
            guard !allLines.isEmpty else { return event }

            let current = button.title
            let idx = allLines.firstIndex(of: current) ?? 0
            let next: Int
            if event.scrollingDeltaY > 0 { next = max(0, idx - 1) }
            else { next = min(allLines.count - 1, idx + 1) }
            button.title = allLines[next].trimmingCharacters(in: .whitespaces)
            return nil
        }
    }

    // MARK: - Click handling

    private func configureClicks() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    var buttonFrameInScreen: NSRect? {
        guard let button = statusItem.button else { return nil }
        let frame = button.frame
        guard let window = button.window else {
            guard let screen = NSScreen.main else { return nil }
            return NSRect(x: screen.frame.midX - frame.width / 2,
                          y: screen.frame.maxY - 24,
                          width: frame.width, height: 22)
        }
        return window.convertToScreen(frame)
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        switch event.type {
        case .leftMouseUp:
            onLeftClick?()
        case .rightMouseUp:
            showContextMenu()
        default:
            break
        }
    }

    // MARK: - Right-click menu

    private func showContextMenu() {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: Loc.tr("openSettings"), action: #selector(openSettingsAction), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let disableItem = NSMenuItem(title: Loc.tr("disablePlugin"), action: #selector(disableAction), keyEquivalent: "")
        disableItem.target = self
        menu.addItem(disableItem)
        let refreshItem = NSMenuItem(title: Loc.tr("refreshNow"), action: #selector(refreshAction), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: Loc.tr("quitDashBar"), action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettingsAction() { onOpenSettings?() }
    @objc private func disableAction() { onDisable?() }
    @objc private func refreshAction() { onRefresh?() }
    @objc private func quitAction() { NSApp.terminate(nil) }

    // MARK: - Default icon

    private static func makeDefaultIcon() -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size))
        image.isTemplate = true
        image.lockFocus()
        let rect = NSRect(x: 3, y: 3, width: size - 6, height: size - 6)
        let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        NSColor.black.setFill()
        path.fill()
        image.unlockFocus()
        return image
    }
}
