import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var pluginHost: PluginHost!
    private var scriptRunner: ScriptRunner!
    private var settingsWindow: SettingsWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        pluginHost = PluginHost()
        scriptRunner = ScriptRunner()

        pluginHost.onOpenSettings = { [weak self] in
            guard let self else { return }
            let descs = self.pluginHost.descriptors()
            self.settingsWindow.show(with: descs, pluginDir: PluginScanner.defaultPluginDir)
        }

        settingsWindow = SettingsWindowController()
        settingsWindow.onTogglePlugin = { [weak self] name, enabled in
            self?.pluginHost.setEnabled(name, enabled: enabled)
            self?.scriptRunner.startAll(descriptors: self?.pluginHost.descriptors() ?? [])
        }

        NotificationCenter.default.addObserver(
            forName: .scriptOutput,
            object: nil,
            queue: .main
        ) { note in
            let name = note.userInfo?["name"] as? String
            let output = note.userInfo?["output"] as? String
            MainActor.assumeIsolated {
                guard let name, let output else { return }
                self.pluginHost.handleScriptOutput(name: name, output: output)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .pluginsChanged,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                self.pluginHost.reload()
                let descs = self.pluginHost.descriptors()
                self.scriptRunner.startAll(descriptors: descs)
                // Also update settings window
                self.settingsWindow.show(
                    with: descs,
                    pluginDir: PluginScanner.defaultPluginDir
                )
            }
        }

        // 1. Load plugins with a short delay so the app is fully ready
        pluginHost.reload()
        let silent = UserDefaults.standard.bool(forKey: "launchSilently")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            let descriptors = self.pluginHost.descriptors()
            self.scriptRunner.startAll(descriptors: descriptors)
            if !silent {
                self.settingsWindow.show(with: descriptors, pluginDir: PluginScanner.defaultPluginDir)
            }
        }

        // 2. Silent / dock preference
    }

    func applicationWillTerminate(_ notification: Notification) {
    }
}
