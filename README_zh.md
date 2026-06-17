# DashBar

macOS 菜单栏插件管理器 — 把你的脚本变成菜单栏小工具。

仿照 [SwiftBar](https://github.com/swiftbar/SwiftBar) 的插件机制和 [Stats](https://github.com/exelban/stats) 的弹出面板风格，用 WKWebView 渲染 HTML 弹窗，每个插件自带一个 NSStatusItem。

## 功能

- **一个插件 = 一个菜单栏图标**：SF Symbols、自定义 PNG/PDF 图标、图标+文本
- **HTML 弹窗**：内置 WKWebView 渲染，支持 JS↔Swift 桥接，自动适配明暗模式
- **定时执行脚本**：文件名约定 `name.{interval}.sh` 或 manifest.json 配置
- **多语言脚本**：shebang 自动检测，支持 bash/python/ruby/node/swift
- **管理窗口**：偏好设置 + 插件管理（启用/禁用），中文/英文
- **开机自启**：通过 SMAppService 注册登录项

## 插件格式

### 文件夹插件（推荐）

```
~/DashBar/plugins/my-plugin/
├── manifest.json    # 名称、间隔、图标、HTML
├── run.sh           # 任意语言（shebang 自动识别）
└── index.html       # 弹窗内容（可选）
```

**manifest.json：**
```json
{
  "name": "Weather",
  "interval": "1m",
  "script": "run.py",
  "html": "index.html",
  "popoverWidth": 380,
  "popoverHeight": 300,
  "sfSymbol": "cloud.sun.fill",
  "showText": false
}
```

| 字段 | 说明 |
|------|------|
| `name` | 显示名称 |
| `interval` | 刷新间隔：`30s`、`10m`、`1h` |
| `script` | 脚本文件名 |
| `html` | 弹窗 HTML（可选，不填则纯文本） |
| `popoverWidth/Height` | 弹窗尺寸 |
| `sfSymbol` | SF Symbols 图标名 |
| `icon` | 自定义图标文件路径 |
| `showText` | 是否在图标旁显示脚本输出文本 |

## HTML 弹窗开发

插件脚本通过 stdout 输出数据，弹窗 HTML 通过 `pushOutput(raw)` 函数接收输出字符串。

### 链接行为控制

WKWebView 默认不在弹窗内导航到外部页面。通过 `data-open` 属性控制 `<a>` 链接的打开方式：

| `data-open` 属性 | 行为 |
|---|---|
| `data-open="browser"` | 在外部浏览器中打开 |
| `data-open="popover"` | 在弹窗内导航 |
| 无 `data-open`（默认） | 在外部浏览器中打开 |

```html
<!-- 外部浏览器：打开必应 -->
<a href="https://bing.com" data-open="browser">去充值</a>

<!-- 弹窗内：切换到设置页 -->
<a href="https://bing.com" data-open="popover">Settings</a>
```

### JS↔Swift 桥接

```
window.webkit.messageHandlers.bridge.postMessage({action: "refresh"})
```

### 明暗模式适配

使用 CSS `@media (prefers-color-scheme: light/dark)` 或 `color-scheme: light dark` + 系统颜色变量（`CanvasText` 等）自动适配。

### 单文件插件（兼容 SwiftBar）

```
~/DashBar/plugins/date.5s.sh    # 每 5 秒执行，显示纯文本
~/DashBar/plugins/uptime.10s.sh # 每 10 秒执行
```

## 构建

```bash
# 开发运行
swift run

# 打包安装
./scripts/package.sh --install
```

## 技术栈

- Swift 6 + AppKit
- WKWebView（HTML 渲染 + JS 桥接）
- NSStatusItem（每个插件独立菜单栏图标）
- NSVisualEffectView（原生毛玻璃弹窗）
- SMAppService（登录项管理）

## 许可

MIT
