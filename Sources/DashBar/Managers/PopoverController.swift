import AppKit

@MainActor
final class PopoverController {

    private let window: NSWindow
    private let visualEffectView: NSVisualEffectView
    private var eventMonitor: Any?
    private var isShown = false

    // Navigation bar
    private let navBar = NSView()
    private let backBtn = PopoverController.makeNavButton(symbol: "chevron.left")
    private let forwardBtn = PopoverController.makeNavButton(symbol: "chevron.right")
    private let homeBtn = PopoverController.makeNavButton(symbol: "house")
    private let navBarHeight: CGFloat = 28
    private var navBarConstraint: NSLayoutConstraint?
    private var webViewTopConstraint: NSLayoutConstraint?
    private var currentWebView: NSView?

    private let defaultSize = NSSize(width: 360, height: 420)

    init() {
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: defaultSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .transient]
        window.isReleasedWhenClosed = false

        visualEffectView = NSVisualEffectView(frame: window.contentView!.bounds)
        visualEffectView.material = .underWindowBackground
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 16
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 0.5
        visualEffectView.layer?.borderColor = NSColor.separatorColor.cgColor
        visualEffectView.autoresizingMask = [.width, .height]

        window.contentView = visualEffectView

        buildNavBar()
    }

    // MARK: - Navigation bar

    private func buildNavBar() {
        navBar.wantsLayer = true
        navBar.isHidden = true
        navBar.translatesAutoresizingMaskIntoConstraints = false

        backBtn.target = self
        backBtn.action = #selector(goBack)
        backBtn.isEnabled = false
        forwardBtn.target = self
        forwardBtn.action = #selector(goForward)
        forwardBtn.isEnabled = false
        homeBtn.target = self
        homeBtn.action = #selector(goHome)
        homeBtn.isEnabled = false

        let stack = NSStackView(views: [backBtn, forwardBtn, NSView(), homeBtn])
        stack.orientation = .horizontal
        stack.spacing = 2
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(stack)

        visualEffectView.addSubview(navBar)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 8),
            navBar.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -8),
            navBar.heightAnchor.constraint(equalToConstant: navBarHeight),
            stack.topAnchor.constraint(equalTo: navBar.topAnchor),
            stack.bottomAnchor.constraint(equalTo: navBar.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -6),
        ])

        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.leadingAnchor.constraint(equalTo: navBar.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: navBar.trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: navBar.bottomAnchor),
            sep.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    private var webController: WebContentController?

    func setContent(_ view: NSView) {
        // Remove old content
        currentWebView?.removeFromSuperview()

        currentWebView = view
        view.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(view)

        // Remove old top constraint if any
        if let old = webViewTopConstraint { old.isActive = false }

        let topAnchor = navBar.isHidden ? visualEffectView.topAnchor : navBar.bottomAnchor
        webViewTopConstraint = view.topAnchor.constraint(equalTo: topAnchor)
        NSLayoutConstraint.activate([
            webViewTopConstraint!,
            view.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
        ])
    }

    func bindWebController(_ wc: WebContentController) {
        webController = wc
        wc.onNavigationStateChanged = { [weak self] in
            self?.updateNavBar()
        }
    }

    private func updateNavBar() {
        guard let wc = webController else { return }

        let shouldShow = !wc.isOnHome
        navBar.isHidden = !shouldShow
        backBtn.isEnabled = wc.canGoBack
        forwardBtn.isEnabled = wc.canGoForward
        homeBtn.isEnabled = !wc.isOnHome

        // Adjust webview top constraint
        if let top = webViewTopConstraint {
            top.isActive = false
            let newTop = shouldShow ? navBar.bottomAnchor : visualEffectView.topAnchor
            webViewTopConstraint = currentWebView?.topAnchor.constraint(equalTo: newTop)
            webViewTopConstraint?.isActive = true
        }
    }

    @objc private func goBack() { webController?.goBack() }
    @objc private func goForward() { webController?.goForward() }
    @objc private func goHome() { webController?.goHome() }

    private static func makeNavButton(symbol: String) -> NSButton {
        let btn = NSButton()
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.title = ""
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            btn.image = img.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            )
            btn.image?.isTemplate = true
        }
        btn.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return btn
    }

    // MARK: - Window sizing

    func resize(to size: NSSize) {
        let newFrame = NSRect(
            x: window.frame.origin.x,
            y: window.frame.origin.y - (size.height - window.frame.height),
            width: size.width,
            height: size.height
        )
        window.setFrame(newFrame, display: true, animate: false)
    }

    func resetSize() {
        resize(to: defaultSize)
    }

    func show(positionBelow buttonFrame: NSRect?) {
        hide()
        guard let buttonFrame else { return }
        reposition(below: buttonFrame)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isShown = true
        startEventMonitor()
    }

    func hide() {
        window.orderOut(nil)
        isShown = false
        stopEventMonitor()
    }

    func toggle(positionBelow buttonFrame: NSRect?) {
        isShown ? hide() : show(positionBelow: buttonFrame)
    }

    private func reposition(below buttonFrame: NSRect) {
        guard let screen = NSScreen.main else { return }

        let x = buttonFrame.midX - window.frame.width / 2
        let topEdge = buttonFrame.minY

        let margin: CGFloat = 8
        let minX = max(screen.visibleFrame.minX + margin, x)
        let maxX = min(screen.visibleFrame.maxX - window.frame.width - margin, x)
        let clampedX = max(minX, min(maxX, x))

        let maxTop = screen.frame.maxY
        let minTop = screen.visibleFrame.minY + window.frame.height
        let clampedTop = max(minTop, min(maxTop, topEdge))

        window.setFrameTopLeftPoint(NSPoint(x: clampedX, y: clampedTop))
    }

    private func startEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return }
            if event.window != self.window {
                self.hide()
            }
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
