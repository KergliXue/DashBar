import Foundation

enum Loc {

    private static let langKey = "DashBarLanguage"

    static var current: String {
        if let forced = UserDefaults.standard.string(forKey: langKey), !forced.isEmpty {
            return forced
        }
        guard let lang = Locale.preferredLanguages.first else { return "en" }
        return lang.hasPrefix("zh") ? "zh" : "en"
    }

    static var isChinese: Bool { current == "zh" }

    static func setLanguage(_ lang: String) {
        UserDefaults.standard.set(lang, forKey: langKey)
    }

    static var availableLanguages: [(code: String, label: String)] {
        [("auto", "Auto"), ("en", "English"), ("zh", "中文")]
    }

    static func tr(_ key: String) -> String {
        dict[key]?[current] ?? key
    }

    private static let dict: [String: [String: String]] = [
        "settings":        ["en": "Settings",                "zh": "设置"],
        "preferences":     ["en": "Preferences",             "zh": "偏好设置"],
        "plugins":         ["en": "Plugins",                 "zh": "插件"],
        "pluginDir":       ["en": "Plugin Directory",        "zh": "插件目录"],
        "openInFinder":    ["en": "Open in Finder",          "zh": "在 Finder 中打开"],
        "refresh":         ["en": "Refresh",                 "zh": "刷新"],
        "newPlugin":       ["en": "New Plugin...",           "zh": "新建插件..."],
        "launchAtLogin":   ["en": "Launch at Login",         "zh": "开机自启动"],
        "launchSilently":  ["en": "Launch Silently (No Window)", "zh": "静默启动（不显示窗口）"],
        "keepInDock":      ["en": "Keep in Dock",            "zh": "保留在 Dock 栏"],
        "restart":         ["en": "Restart DashBar",         "zh": "重启 DashBar"],
        "restarting":      ["en": "Restarting...",           "zh": "正在重启..."],
        "on":              ["en": "On",                      "zh": "开"],
        "name":            ["en": "Name",                    "zh": "名称"],
        "icon":            ["en": "Icon",                    "zh": "图标"],
        "interval":        ["en": "Interval",                "zh": "间隔"],
        "page":            ["en": "Page",                    "zh": "页面"],
        "script":          ["en": "Script",                  "zh": "脚本"],
        "once":            ["en": "once",                    "zh": "单次"],
        "yes":             ["en": "Yes",                     "zh": "是"],
        "no":              ["en": "—",                       "zh": "—"],
        "pluginCount":     ["en": "{0}/{1} enabled",         "zh": "{0}/{1} 已启用"],
        "doubleClickHint": ["en": "Double-click to open in Finder.", "zh": "双击可在 Finder 中打开。"],
        "newPluginHelp":   ["en": "Create a folder with manifest.json + script under the plugin directory.", "zh": "在插件目录下创建包含 manifest.json 和脚本的文件夹。"],
        "language":        ["en": "Language",                "zh": "语言"],
        "restartForLang":  ["en": "Restart DashBar to apply language change.", "zh": "重启 DashBar 以应用语言更改。"],
        "openSettings":    ["en": "Open Settings",          "zh": "打开设置"],
        "disablePlugin":   ["en": "Disable Plugin",         "zh": "关闭插件"],
        "refreshNow":      ["en": "Refresh Now",            "zh": "立即刷新"],
        "quitDashBar":     ["en": "Quit DashBar",           "zh": "退出 DashBar"],
        "closePopoverOnExternalLink": ["en": "Close popover after opening external link", "zh": "外部链接打开后自动关闭弹窗"],
        "transparency":     ["en": "Transparency",            "zh": "透明度"],
        "transparency_glass":  ["en": "Frosted Glass",        "zh": "毛玻璃"],
        "transparency_medium": ["en": "Medium Blur",           "zh": "中等模糊"],
        "transparency_light":  ["en": "Light Blur",            "zh": "轻度模糊"],
        "transparency_solid":  ["en": "Solid",                 "zh": "不透明"],
    ]
}
