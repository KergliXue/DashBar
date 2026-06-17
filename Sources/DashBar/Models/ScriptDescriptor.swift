import Foundation

struct PluginManifest: Codable {
    var name: String
    var interval: String?
    var script: String
    var html: String?
    var popoverWidth: Double?
    var popoverHeight: Double?
    var sfSymbol: String?
    var icon: String?
    var showText: Bool?
    var enabled: Bool?
}

/// Represents a parsed plugin: one plugin = one NSStatusItem + one popover
struct ScriptDescriptor {
    let name: String
    let path: String
    let interval: TimeInterval?
    let htmlPath: String?
    let popoverSize: NSSize?
    let interpreter: String
    let sfSymbol: String?
    let iconPath: String?
    let showText: Bool
    let pluginDir: URL

    /// Enabled state (loaded from manifest or state file)
    var enabled: Bool

    init(
        name: String,
        path: String,
        interval: TimeInterval?,
        htmlPath: String? = nil,
        popoverSize: NSSize? = nil,
        interpreter: String = "/bin/sh",
        sfSymbol: String? = nil,
        iconPath: String? = nil,
        showText: Bool = false,
        pluginDir: URL,
        enabled: Bool = true
    ) {
        self.name = name
        self.path = path
        self.interval = interval
        self.htmlPath = htmlPath
        self.popoverSize = popoverSize
        self.interpreter = interpreter
        self.sfSymbol = sfSymbol
        self.iconPath = iconPath
        self.showText = showText
        self.pluginDir = pluginDir
        self.enabled = enabled
    }
}

