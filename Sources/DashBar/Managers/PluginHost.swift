import AppKit

/// The central plugin host. Scans plugins, creates one NSStatusItem + one popover per plugin.
@MainActor
final class PluginHost {

    var onOpenSettings: (() -> Void)?

    private var items: [String: PluginStatusItem] = [:]
    private var popovers: [String: PopoverController] = [:]
    private var webControllers: [String: WebContentController] = [:]
    private var outputCache: [String: String] = [:]

    func reload() {
        let scanner = PluginScanner()
        let descriptors = scanner.scan()
        let newNames = Set(descriptors.map { $0.name })

        for name in items.keys where !newNames.contains(name) {
            removePlugin(name)
        }

        for desc in descriptors {
            if let existing = items[desc.name] {
                if desc.enabled != existing.descriptor.enabled {
                    if desc.enabled { enablePlugin(desc) } else { disablePlugin(desc.name) }
                }
                // Always replay cached output for existing items (even if newly re-enabled)
                if desc.enabled, let cached = outputCache[desc.name] {
                    items[desc.name]?.updateButtonText(cached)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.webControllers[desc.name]?.pushOutputToJS(output: cached)
                    }
                }
            } else if desc.enabled {
                addPlugin(desc)
            }
        }
    }

    private func addPlugin(_ descriptor: ScriptDescriptor) {
        let item = PluginStatusItem(descriptor: descriptor)
        let popover = PopoverController()
        let webController = WebContentController()

        popover.setContent(webController.webView)
        popover.bindWebController(webController)

        if let htmlPath = descriptor.htmlPath {
            webController.loadPluginHTML(path: htmlPath, pluginName: descriptor.name)
        } else {
            webController.loadFallbackContent(pluginName: descriptor.name)
        }

        // Left click: toggle popover
        item.onLeftClick = { [weak item, weak popover] in
            guard let item, let popover else { return }
            popover.toggle(positionBelow: item.buttonFrameInScreen)
        }

        // Right-click menu actions
        item.onOpenSettings = { [weak self] in self?.onOpenSettings?() }
        item.onDisable = { [weak self] in self?.setEnabled(descriptor.name, enabled: false) }
        item.onRefresh = {
            Task { await ScriptRunner.runScript(descriptor: descriptor) }
        }

        webController.onBridgeMessage = { [weak self] _, body in
            self?.handleBridgeMessage(pluginName: descriptor.name, body: body)
        }

        items[descriptor.name] = item
        popovers[descriptor.name] = popover
        webControllers[descriptor.name] = webController

        // Replay cached output after a short delay so webview has time to load
        if let cached = outputCache[descriptor.name] {
            item.updateButtonText(cached)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak webController, cached] in
                webController?.pushOutputToJS(output: cached)
            }
        }
    }

    private func removePlugin(_ name: String) {
        disablePlugin(name)
        items[name] = nil
        popovers[name] = nil
        webControllers[name] = nil
        outputCache[name] = nil
    }

    private func enablePlugin(_ descriptor: ScriptDescriptor) {
        addPlugin(descriptor)
    }

    func disablePlugin(_ name: String) {
        items[name] = nil
        popovers[name] = nil
        webControllers[name] = nil
    }

    func setEnabled(_ name: String, enabled: Bool) {
        if enabled, let desc = descriptors().first(where: { $0.name == name }) {
            addPlugin(desc)
        } else if !enabled {
            disablePlugin(name)
        }
        PluginScanner.saveEnabledState(pluginName: name, enabled: enabled)
    }

    func handleScriptOutput(name: String, output: String) {
        outputCache[name] = output
        items[name]?.updateButtonText(output)
        webControllers[name]?.pushOutputToJS(output: output)
    }

    func descriptors() -> [ScriptDescriptor] {
        PluginScanner().scan()
    }

    private func handleBridgeMessage(pluginName: String, body: Any) {
        guard let dict = body as? [String: Any],
              let action = dict["action"] as? String
        else { return }
        switch action {
        case "refresh":
            if let desc = items[pluginName]?.descriptor {
                Task { await ScriptRunner.runScript(descriptor: desc) }
            }
        default:
            break
        }
    }
}
