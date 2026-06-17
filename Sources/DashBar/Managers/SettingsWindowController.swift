import AppKit

@MainActor
final class SettingsWindowController: NSObject {

    let window: NSWindow
    var onTogglePlugin: ((String, Bool) -> Void)?

    private var pluginList: [ScriptDescriptor] = []
    private var pluginEnabled: [Bool] = []

    // MARK: - UI elements
    private var tabView: NSTabView!
    private var pluginTableView: NSTableView!
    private var statusLabel: NSTextField!
    private var pluginNames: [String] = []
    private var pluginIntervals: [String] = []
    private var pluginSymbols: [String] = []

    // Preferences controls
    private var launchAtLoginCheckbox: NSButton!
    private var launchSilentlyCheckbox: NSButton!
    private var keepInDockCheckbox: NSButton!
    private var closePopoverOnExternalLinkCheckbox: NSButton!

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = Loc.tr("settings")
        window.titlebarAppearsTransparent = true
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 500, height: 380)
        window.delegate = self

        window.contentView = buildContent()
        loadPreferences()
    }

    func show(with plugins: [ScriptDescriptor], pluginDir _: URL) {
        pluginList = plugins
        pluginEnabled = plugins.map { $0.enabled }
        reloadPluginTable()
        showInDock()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showInDock() {
        NSApp.setActivationPolicy(.regular)
    }

    private func hideFromDock() {
        if !window.isVisible {
            let keep = keepInDockCheckbox?.state == .on
            NSApp.setActivationPolicy(keep ? .regular : .accessory)
        }
    }

    // MARK: - Build

    private func buildContent() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 520))

        // Tabs
        tabView = NSTabView(frame: NSRect(x: 20, y: 12, width: 600, height: 492))
        tabView.tabViewType = .topTabsBezelBorder

        let prefsTab = NSTabViewItem(identifier: "prefs")
        prefsTab.label = Loc.tr("preferences")
        prefsTab.view = buildPreferencesTab()
        tabView.addTabViewItem(prefsTab)

        let pluginsTab = NSTabViewItem(identifier: "plugins")
        pluginsTab.label = Loc.tr("plugins")
        pluginsTab.view = buildPluginsTab()
        tabView.addTabViewItem(pluginsTab)

        container.addSubview(tabView)

        return container
    }

    // MARK: - Preferences Tab

    private func buildPreferencesTab() -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 580, height: 450))
        let y0: CGFloat = 410

        let title = NSTextField(labelWithString: Loc.tr("preferences"))
        title.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        title.frame = NSRect(x: 20, y: y0, width: 200, height: 24)
        v.addSubview(title)

        // Launch at login
        launchAtLoginCheckbox = NSButton(checkboxWithTitle: Loc.tr("launchAtLogin"), target: self, action: #selector(toggleLaunchAtLogin))
        launchAtLoginCheckbox.frame = NSRect(x: 20, y: y0 - 40, width: 540, height: 22)
        launchAtLoginCheckbox.controlSize = .small
        v.addSubview(launchAtLoginCheckbox)

        // Launch silently
        launchSilentlyCheckbox = NSButton(checkboxWithTitle: Loc.tr("launchSilently"), target: self, action: #selector(toggleLaunchSilently))
        launchSilentlyCheckbox.frame = NSRect(x: 36, y: y0 - 68, width: 524, height: 22)
        launchSilentlyCheckbox.controlSize = .small
        v.addSubview(launchSilentlyCheckbox)

        // Keep in Dock
        keepInDockCheckbox = NSButton(checkboxWithTitle: Loc.tr("keepInDock"), target: self, action: #selector(toggleKeepInDock))
        keepInDockCheckbox.frame = NSRect(x: 20, y: y0 - 100, width: 540, height: 22)
        keepInDockCheckbox.controlSize = .small
        v.addSubview(keepInDockCheckbox)

        // Close popover on external link
        closePopoverOnExternalLinkCheckbox = NSButton(checkboxWithTitle: Loc.tr("closePopoverOnExternalLink"), target: self, action: #selector(toggleClosePopoverOnExternalLink))
        closePopoverOnExternalLinkCheckbox.frame = NSRect(x: 20, y: y0 - 132, width: 540, height: 22)
        closePopoverOnExternalLinkCheckbox.controlSize = .small
        v.addSubview(closePopoverOnExternalLinkCheckbox)

        // Language selector
        let langLabel = NSTextField(labelWithString: Loc.tr("language"))
        langLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        langLabel.frame = NSRect(x: 20, y: y0 - 174, width: 100, height: 18)
        v.addSubview(langLabel)

        let langPopup = NSPopUpButton(frame: NSRect(x: 120, y: y0 - 178, width: 120, height: 22))
        langPopup.controlSize = .small
        for lang in Loc.availableLanguages {
            langPopup.addItem(withTitle: lang.label)
            langPopup.lastItem?.identifier = NSUserInterfaceItemIdentifier(lang.code)
        }
        // Select current
        for item in langPopup.itemArray {
            if item.identifier?.rawValue == Loc.current {
                langPopup.select(item)
            } else if item.identifier?.rawValue == "auto" && UserDefaults.standard.string(forKey: "DashBarLanguage") == nil {
                langPopup.select(item)
            }
        }
        langPopup.target = self
        langPopup.action = #selector(changeLanguage(_:))
        v.addSubview(langPopup)

        let langHint = NSTextField(labelWithString: Loc.tr("restartForLang"))
        langHint.font = NSFont.systemFont(ofSize: 9)
        langHint.textColor = .tertiaryLabelColor
        langHint.frame = NSRect(x: 250, y: y0 - 176, width: 300, height: 14)
        v.addSubview(langHint)

        // Separator
        let sep = NSBox(frame: NSRect(x: 20, y: y0 - 212, width: 540, height: 1))
        sep.boxType = .separator
        v.addSubview(sep)

        // Restart
        let restartBtn = NSButton(title: Loc.tr("restart"), target: self, action: #selector(restartDashBar))
        restartBtn.bezelStyle = .rounded
        restartBtn.controlSize = .small
        restartBtn.frame = NSRect(x: 20, y: y0 - 247, width: 150, height: 24)
        v.addSubview(restartBtn)

        return v
    }

    // MARK: - Plugins Tab

    private func buildPluginsTab() -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 580, height: 450))

        let title = NSTextField(labelWithString: Loc.tr("plugins"))
        title.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        title.frame = NSRect(x: 20, y: 412, width: 200, height: 24)
        v.addSubview(title)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .right
        statusLabel.frame = NSRect(x: 380, y: 416, width: 196, height: 16)
        v.addSubview(statusLabel)

        // Buttons
        let revealBtn = NSButton(title: Loc.tr("openInFinder"), target: self, action: #selector(openPluginDir))
        revealBtn.bezelStyle = .rounded
        revealBtn.controlSize = .small
        revealBtn.frame = NSRect(x: 20, y: 378, width: 120, height: 22)
        v.addSubview(revealBtn)

        let refreshBtn = NSButton(title: Loc.tr("refresh"), target: self, action: #selector(refreshPlugins))
        refreshBtn.bezelStyle = .rounded
        refreshBtn.controlSize = .small
        refreshBtn.frame = NSRect(x: 146, y: 378, width: 80, height: 22)
        v.addSubview(refreshBtn)

        let newBtn = NSButton(title: Loc.tr("newPlugin"), target: self, action: #selector(newPlugin))
        newBtn.bezelStyle = .rounded
        newBtn.controlSize = .small
        newBtn.frame = NSRect(x: 232, y: 378, width: 120, height: 22)
        v.addSubview(newBtn)

        let sep = NSBox(frame: NSRect(x: 20, y: 362, width: 556, height: 1))
        sep.boxType = .separator
        v.addSubview(sep)

        // Table
        let scroll = NSScrollView(frame: NSRect(x: 20, y: 40, width: 556, height: 316))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        pluginTableView = NSTableView(frame: scroll.bounds)
        pluginTableView.headerView = NSTableHeaderView()

        let cols: [(String, String, CGFloat)] = [
            ("enabled",  Loc.tr("on"),   36),
            ("name",     Loc.tr("name"), 130),
            ("symbol",   Loc.tr("icon"), 80),
            ("interval", Loc.tr("interval"), 70),
            ("page",     Loc.tr("page"),  50),
            ("path",     Loc.tr("script"), 170),
        ]
        for (id, title, w) in cols {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            col.title = title
            col.width = w
            pluginTableView.addTableColumn(col)
        }

        pluginTableView.dataSource = self
        pluginTableView.delegate = self
        pluginTableView.doubleAction = #selector(doubleClickPlugin)
        pluginTableView.target = self
        scroll.documentView = pluginTableView
        v.addSubview(scroll)

        let footer = NSTextField(labelWithString: Loc.tr("doubleClickHint"))
        footer.font = NSFont.systemFont(ofSize: 9)
        footer.textColor = .tertiaryLabelColor
        footer.frame = NSRect(x: 20, y: 20, width: 540, height: 14)
        v.addSubview(footer)

        return v
    }

    // MARK: - Plugin table helpers

    func reloadPluginTable() {
        pluginNames = pluginList.map { $0.name }
        pluginIntervals = pluginList.map { d in
            guard let i = d.interval else { return Loc.tr("once") }
            if i < 60 { return "\(Int(i))s" }
            if i < 3600 { return "\(Int(i / 60))m" }
            return "\(Int(i / 3600))h"
        }
        pluginSymbols = pluginList.map { $0.sfSymbol ?? $0.iconPath ?? "—" }
        pluginTableView.reloadData()
        let n = pluginEnabled.filter { $0 }.count
        statusLabel.stringValue = Loc.tr("pluginCount").replacing("{0}", with: "\(n)").replacing("{1}", with: "\(pluginList.count)")
    }

    // MARK: - Preferences: login item

    private func loadPreferences() {
        launchAtLoginCheckbox.state = LoginItemHelper.isEnabled ? .on : .off
        launchSilentlyCheckbox.state = UserDefaults.standard.bool(forKey: "launchSilently") ? .on : .off
        keepInDockCheckbox.state = UserDefaults.standard.bool(forKey: "keepInDock") ? .on : .off
        launchSilentlyCheckbox.isEnabled = launchAtLoginCheckbox.state == .on
        if UserDefaults.standard.object(forKey: "closePopoverOnExternalLink") == nil {
            UserDefaults.standard.set(true, forKey: "closePopoverOnExternalLink")
        }
        closePopoverOnExternalLinkCheckbox.state = UserDefaults.standard.bool(forKey: "closePopoverOnExternalLink") ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        let on = launchAtLoginCheckbox.state == .on
        LoginItemHelper.setEnabled(on)
        launchSilentlyCheckbox.isEnabled = on
    }

    @objc private func toggleLaunchSilently() {
        UserDefaults.standard.set(launchSilentlyCheckbox.state == .on, forKey: "launchSilently")
    }

    @objc private func toggleKeepInDock() {
        let keep = keepInDockCheckbox.state == .on
        UserDefaults.standard.set(keep, forKey: "keepInDock")
        if window.isVisible {
            NSApp.setActivationPolicy(keep ? .regular : .accessory)
        }
    }

    @objc private func toggleClosePopoverOnExternalLink() {
        UserDefaults.standard.set(closePopoverOnExternalLinkCheckbox.state == .on, forKey: "closePopoverOnExternalLink")
    }

    @objc private func changeLanguage(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else { return }
        let code = item.identifier?.rawValue ?? "auto"
        if code == "auto" {
            UserDefaults.standard.removeObject(forKey: "DashBarLanguage")
        } else {
            Loc.setLanguage(code)
        }
    }

    @objc private func restartDashBar() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        let appPath = Bundle.main.bundlePath
        task.arguments = ["open", "-n", appPath]
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: - Plugin actions

    @objc private func openPluginDir() {
        NSWorkspace.shared.open(PluginScanner.defaultPluginDir)
    }

    @objc private func refreshPlugins() {
        let scanner = PluginScanner()
        pluginList = scanner.scan()
        pluginEnabled = pluginList.map { $0.enabled }
        reloadPluginTable()
        NotificationCenter.default.post(name: .pluginsChanged, object: nil)
    }

    @objc private func newPlugin() {
        let a = NSAlert()
        a.messageText = Loc.tr("newPlugin")
        a.informativeText = Loc.tr("newPluginHelp")
        a.alertStyle = .informational
        a.addButton(withTitle: Loc.tr("openInFinder"))
        a.addButton(withTitle: "Cancel")
        if a.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(PluginScanner.defaultPluginDir)
        }
    }

    @objc private func doubleClickPlugin() {
        let row = pluginTableView.clickedRow
        guard row >= 0, row < pluginList.count else { return }
        let url = URL(fileURLWithPath: pluginList[row].path).deletingLastPathComponent()
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleCheckbox(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0, row < pluginList.count else { return }
        let state = sender.state == .on
        pluginEnabled[row] = state
        pluginList[row].enabled = state
        onTogglePlugin?(pluginList[row].name, state)
        reloadPluginTable()
    }
}

// MARK: - NSWindowDelegate

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        hideFromDock()
    }
}

// MARK: - NSTableView

extension SettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { pluginNames.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < pluginList.count else { return nil }

        let id = tableColumn?.identifier.rawValue
        if id == "enabled" {
            let btn = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleCheckbox(_:)))
            btn.state = pluginEnabled[row] ? .on : .off
            btn.tag = row
            btn.controlSize = .small
            return btn
        }

        let text: String
        switch id {
        case "name":     text = pluginList[row].name
        case "symbol":   text = pluginSymbols[row]
        case "interval": text = pluginIntervals[row]
        case "page":     text = pluginList[row].htmlPath != nil ? Loc.tr("yes") : Loc.tr("no")
        case "path":     text = abbreviate(pluginList[row].path)
        default:         text = ""
        }

        let tf = NSTextField(labelWithString: text)
        if id == "name" { tf.font = NSFont.systemFont(ofSize: 12, weight: .medium) }
        else { tf.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular) }
        if !pluginEnabled[row] { tf.textColor = .disabledControlTextColor }
        return tf
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 24 }

    private func abbreviate(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }
}

extension Notification.Name {
    static let pluginsChanged = Notification.Name("DashBarPluginsChanged")
}
