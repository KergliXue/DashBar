import WebKit

@MainActor
final class WebContentController: NSObject {

    let webView: WKWebView
    var onBridgeMessage: ((String, Any) -> Void)?

    /// Called when the navigation stack changes (back/forward availability, url change).
    /// PopoverController uses this to show/hide the nav bar.
    var onNavigationStateChanged: (() -> Void)?

    /// Called when a link is opened in the external browser (no data-open or data-open="browser").
    var onOpenExternalURL: (() -> Void)?

    /// The original home URL — loaded for the plugin
    private var homeURL: URL?
    /// Did we ever navigate away from the home page?
    private var hasNavigated: Bool { homeURL != nil && webView.url != homeURL }
    /// Last output pushed via pushOutputToJS, replayed when navigating back home
    private var lastOutput: String?

    override init() {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.userContentController = userContentController
        config.defaultWebpagePreferences = prefs

        webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        super.init()

        webView.configuration.userContentController.add(self, name: "bridge")
        webView.navigationDelegate = self
    }

    func loadPluginHTML(path: String, pluginName _: String) {
        let url = URL(fileURLWithPath: path)
        homeURL = url
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func loadFallbackContent(pluginName: String) {
        homeURL = nil  // fallback HTML has no "home" to go back to
        let html = """
        <!DOCTYPE html><html><head><meta charset=\"utf-8\"><style>
        :root{color-scheme:light dark}
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:-apple-system,sans-serif;background:transparent;padding:20px;user-select:none;-webkit-user-select:none;color:CanvasText}
        .name{font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.6px;margin-bottom:12px;color:GrayText}
        pre{font-size:13px;line-height:1.5;white-space:pre-wrap;word-break:break-word}
        </style></head><body>
        <div class="name">\(pluginName)</div>
        <pre id="output">Waiting...</pre>
        <script>
        function pushOutput(raw){document.getElementById('output').textContent=raw}
        </script>
        </body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    func pushOutputToJS(output: String) {
        lastOutput = output
        let escaped = output
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        let js = "if(typeof pushOutput==='function'){pushOutput(`\(escaped)`);}"
        webView.evaluateJavaScript(js)
    }

    // MARK: - Navigation actions

    var canGoBack: Bool { webView.canGoBack || hasNavigated }
    var canGoForward: Bool { webView.canGoForward }

    func goBack() {
        if webView.canGoBack {
            webView.goBack()
        } else if hasNavigated {
            goHome()
        }
    }

    func goForward() {
        if webView.canGoForward { webView.goForward() }
    }

    func goHome() {
        guard let home = homeURL else { return }
        webView.loadFileURL(home, allowingReadAccessTo: home.deletingLastPathComponent())
    }

    var isOnHome: Bool {
        guard let home = homeURL else { return webView.url == nil || webView.url?.absoluteString.contains("about:blank") == true }
        return webView.url == home
    }

    func cleanup() {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "bridge")
        webView.stopLoading()
    }
}

// MARK: - WKNavigationDelegate

extension WebContentController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Inject link-click interceptor
        let js = """
        (function(){
          if(window.__dashBarLinkInterceptor) return;
          window.__dashBarLinkInterceptor = true;
          document.addEventListener('click', function(e){
            var a = e.target.closest('a[href]');
            if(!a) return;
            var mode = a.getAttribute('data-open') || 'browser';
            if(mode === 'popover') return;
            e.preventDefault();
            var url = a.href;
            window.webkit.messageHandlers.bridge.postMessage({action:'openURL', url:url});
          });
        })();
        """
        webView.evaluateJavaScript(js)

        // Replay cached output when returning to the home page (goHome re-loads the file, which resets "Loading...")
        if isOnHome, let lastOutput {
            pushOutputToJS(output: lastOutput)
        }

        // Notify host that navigation state changed (to show/hide nav bar)
        onNavigationStateChanged?()
    }
}

// MARK: - WKScriptMessageHandler

extension WebContentController: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let dict = message.body as? [String: Any],
               dict["action"] as? String == "openURL",
               let urlStr = dict["url"] as? String,
               let url = URL(string: urlStr) {
                NSWorkspace.shared.open(url)
                Task { @MainActor [weak self] in
                    self?.onOpenExternalURL?()
                }
            } else {
                self.onBridgeMessage?(message.name, message.body)
            }
        }
    }
}
