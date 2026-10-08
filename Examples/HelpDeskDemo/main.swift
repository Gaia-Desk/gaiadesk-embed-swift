// HelpDeskDemo: an AppKit app with a "Get help" button.
//
//   GAIADESK_EMBED_TOKEN=gdemb_… [GAIADESK_SERVER=https://gaiadesk.net] swift run HelpDeskDemo
//
// Your backend creates the support session (POST /v1/support/sessions with a
// secret key) and hands the app the embed token; here it comes from the
// environment or the text field. The red "card number" box is masked: your
// support team sees it painted black.
//
// GAIADESK_DEMO_GUIDED=1 allows guided input (the session must be "cobrowse").
// GAIADESK_DEMO_AUTOSTART=1 presses Get help at launch, and — for automated
// tests only — GAIADESK_DEMO_TEST_CONSENT=1 answers the consent dialog
// "Share" itself. Every event is printed to stdout as one JSON line.

import AppKit
import GaiaDeskEmbed

let env = ProcessInfo.processInfo.environment

func emit(_ obj: [String: Any]) {
    if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]), let s = String(data: d, encoding: .utf8) {
        print(s)
        fflush(stdout)
    }
}

final class Swatch: NSView {
    let color: NSColor
    init(_ color: NSColor, frame: NSRect) {
        self.color = color
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { nil }
    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        dirtyRect.fill()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var help: GaiaDeskEmbed?
    let token = NSTextField(string: env["GAIADESK_EMBED_TOKEN"] ?? "")
    let status = NSTextField(labelWithString: "Press Get help to share this window with Acme support.")
    let card = Swatch(.systemRed, frame: NSRect(x: 40, y: 220, width: 200, height: 120))
    let blue = Swatch(.systemBlue, frame: NSRect(x: 400, y: 220, width: 200, height: 120))
    var clicks = 0
    var buy: NSButton!
    let clickLabel = NSTextField(labelWithString: "Buy clicked 0 times")

    func applicationDidFinishLaunching(_ note: Notification) {
        window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 640, height: 400), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Acme Desk"
        let content = Swatch(.systemGreen, frame: NSRect(x: 0, y: 0, width: 640, height: 400))
        window.contentView = content
        let cardLabel = NSTextField(labelWithString: "Card 4242 4242 4242 4242")
        cardLabel.frame = NSRect(x: 10, y: 50, width: 190, height: 20)
        card.addSubview(cardLabel)
        for v in [card, blue] { content.addSubview(v) }
        token.frame = NSRect(x: 40, y: 120, width: 420, height: 24)
        token.placeholderString = "gdemb_… (from your backend)"
        content.addSubview(token)
        let get = NSButton(title: "Get help", target: self, action: #selector(getHelp))
        get.frame = NSRect(x: 470, y: 118, width: 130, height: 30)
        content.addSubview(get)
        buy = NSButton(title: "Buy", target: self, action: #selector(buyPressed))
        buy.frame = NSRect(x: 260, y: 160, width: 120, height: 40)
        content.addSubview(buy)
        clickLabel.frame = NSRect(x: 40, y: 80, width: 300, height: 20)
        content.addSubview(clickLabel)
        status.frame = NSRect(x: 40, y: 30, width: 560, height: 40)
        content.addSubview(status)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let box = { (v: NSView) -> [Double] in
            let r = GaiaDeskEmbed.rectInWindow(v) ?? .zero
            return [r.origin.x, r.origin.y, r.width, r.height].map { Double($0) }
        }
        // Where things are, in the window's top-left space (tests sample the picture there).
        emit(["type": "demo", "window": window.windowNumber, "build": GaiaDeskEmbed.buildInfo, "pid": ProcessInfo.processInfo.processIdentifier,
              "frame": [Double(window.frame.width), Double(window.frame.height)], "card": box(card), "blue": box(blue), "buy": box(buy)])
        if env["GAIADESK_DEMO_AUTOSTART"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.getHelp() }
        }
    }

    @objc func buyPressed() {
        clicks += 1
        clickLabel.stringValue = "Buy clicked \(clicks) times"
        emit(["type": "demo", "bought": clicks])
    }

    @objc func getHelp() {
        if help != nil { return }
        let guided = env["GAIADESK_DEMO_GUIDED"] == "1"
        let agreed: Bool
        if env["GAIADESK_DEMO_TEST_CONSENT"] == "1" {
            agreed = true // automated tests only: never ship this
        } else {
            agreed = GaiaDeskEmbed.requestConsent(company: "Acme", capture: .window, guided: guided) ?? false
        }
        guard agreed else {
            status.stringValue = "Not shared."
            emit(["type": "demo", "consent": false])
            return
        }
        var config = GaiaDeskEmbed.Configuration(embedToken: (env["GAIADESK_EMBED_TOKEN"] ?? token.stringValue).trimmingCharacters(in: .whitespaces), company: "Acme", windowNumber: window.windowNumber, guided: guided)
        if let s = env["GAIADESK_SERVER"] { config.server = URL(string: s) }
        do {
            let h = try GaiaDeskEmbed.start(config, consentGranted: true) { [weak self] e in self?.on(e) }
            help = h
            try h.setMaskedViews([card])
        } catch let e as GaiaDeskEmbedError {
            status.stringValue = "Could not start: \(e.message)"
            emit(["type": "demo", "start_error": e.code])
        } catch {
            status.stringValue = "Could not start: \(error)"
        }
    }

    func on(_ e: GaiaDeskEmbed.Event) {
        switch e {
        case let .code(code, sessionId, mode):
            status.stringValue = "Support code \(code) — read it to the Acme agent."
            emit(["type": "code", "code": code, "session_id": sessionId, "mode": mode])
        case let .joined(agent):
            status.stringValue = "\(agent ?? "An agent") is viewing this window."
            emit(["type": "joined", "agent": agent ?? NSNull()])
        case .left:
            emit(["type": "left"])
        case let .state(s):
            emit(["type": "state", "state": s])
        case let .control(allowed):
            emit(["type": "control", "allowed": allowed])
        case let .action(name, applied, reason):
            emit(["type": "action", "action": name, "applied": applied, "reason": reason ?? NSNull()])
        case let .error(code, message):
            emit(["type": "error", "code": code, "message": message])
        case let .ended(reason):
            status.stringValue = "Sharing ended (\(reason))."
            help = nil
            emit(["type": "ended", "reason": reason])
            if env["GAIADESK_DEMO_AUTOSTART"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ note: Notification) {
        help?.stop()
    }
}

// stdin "stop" ends the session, "pause"/"resume" pause guided input (tests).
FileHandle.standardInput.readabilityHandler = { h in
    let data = h.availableData
    if data.isEmpty {
        h.readabilityHandler = nil
        return
    }
    let text = String(decoding: data, as: UTF8.self)
    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            let help = (NSApp.delegate as? AppDelegate)?.help
            if text.contains("pause") { help?.setPaused(true) }
            if text.contains("resume") { help?.setPaused(false) }
            if text.contains("stop") { help?.stop() }
        }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
