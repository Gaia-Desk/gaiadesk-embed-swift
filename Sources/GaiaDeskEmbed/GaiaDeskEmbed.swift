// GaiaDeskEmbed: share your app's window with your support team, from a
// "Get help" button. A thin Swift layer over libgaiadesk_embed's C API.
//
// What the library itself enforces (no wrapper can skip it): it refuses to
// start without consent; its own "Sharing with <company>" panel is up for as
// long as anything is shared; only this app's window is captured unless you
// ask for the screen; the rects you mask are painted out of every frame;
// input is off unless you allow `guided` AND the session is "cobrowse", and
// then lands only in this app's own windows while it is in front.

import AppKit
import Foundation
import GaiaDeskEmbedFFI

/// A refusal from the library: `code` is stable (`consent_required`,
/// `bad_token`, `bad_config`, …), `message` is for people.
public struct GaiaDeskEmbedError: Error, Equatable, CustomStringConvertible {
    public let code: String
    public let message: String
    public var description: String { "\(code): \(message)" }
}

public final class GaiaDeskEmbed {
    /// What is shared.
    public enum Capture: String, Sendable {
        /// One window of this app (the default).
        case window
        /// Every window of this app.
        case app
        /// The whole display this app's window is on (opt-in).
        case screen
    }

    public struct Configuration: Sendable {
        /// `gdemb_…`, from your backend (`POST /v1/support/sessions`).
        public var embedToken: String
        /// Default `https://gaiadesk.net`.
        public var server: URL?
        /// Shown on the consent dialog and the indicator.
        public var company: String
        public var capture: Capture
        /// The window to share (`NSWindow.windowNumber`); default: this app's frontmost.
        public var windowNumber: Int?
        /// Allow guided input (the session must be "cobrowse" too).
        public var guided: Bool
        /// 1 to 30.
        public var fps: Int
        /// Regions painted out from the very first frame (window-relative,
        /// top-left origin, points: `rectInWindow` gives one for a view).
        /// Pass the ones you know here; `setMaskedRects` replaces them later.
        public var maskedRects: [CGRect]

        public init(embedToken: String, company: String, server: URL? = nil, capture: Capture = .window, windowNumber: Int? = nil, guided: Bool = false, fps: Int = 15, maskedRects: [CGRect] = []) {
            self.embedToken = embedToken
            self.server = server
            self.company = company
            self.capture = capture
            self.windowNumber = windowNumber
            self.guided = guided
            self.fps = fps
            self.maskedRects = maskedRects
        }
    }

    public enum Event: Equatable, Sendable {
        case state(String)
        case code(String, sessionId: String, mode: String)
        case joined(agent: String?)
        case left
        case control(allowed: Bool)
        case action(String, applied: Bool, reason: String?)
        case error(code: String, message: String)
        case ended(reason: String)
    }

    /// The library's version ("0.1.0").
    public static var version: String { String(cString: gd_embed_version()) }

    /// What the bundled binary is (JSON: version, codec, os, arch, test_source).
    public static var buildInfo: String { String(cString: gd_embed_build_info()) }

    /// The library's default consent dialog. Main thread. Returns whether the
    /// user agreed; `nil` when called off the main thread.
    @MainActor
    public static func requestConsent(company: String, capture: Capture = .window, guided: Bool = false) -> Bool? {
        switch gd_embed_show_consent(company, capture.rawValue, guided ? 1 : 0) {
        case 1: return true
        case 0: return false
        default: return nil
        }
    }

    private var handle: OpaquePointer?
    private let box: EventBox

    /// Start sharing. `consentGranted` must be your user's answer to a
    /// consent dialog (`requestConsent`, or your own): the library refuses
    /// without it. `onEvent` is called on the main queue.
    public static func start(_ config: Configuration, consentGranted: Bool, onEvent: @escaping (Event) -> Void) throws -> GaiaDeskEmbed {
        let json = try configJSON(config, consentGranted: consentGranted)
        let box = EventBox(onEvent)
        let ctx = Unmanaged.passRetained(box).toOpaque()
        let cb = GdEmbedCallbacks(on_event: { userData, eventJSON in
            guard let userData, let eventJSON else { return }
            let box = Unmanaged<EventBox>.fromOpaque(userData).takeUnretainedValue()
            let text = String(cString: eventJSON)
            let event = GaiaDeskEmbed.parse(text)
            if case .some(.ended) = event {
                // The last event: drop the reference the library held.
                DispatchQueue.main.async {
                    box.deliver(event)
                    Unmanaged<EventBox>.fromOpaque(userData).release()
                }
            } else if let event {
                DispatchQueue.main.async { box.deliver(event) }
            }
        }, user_data: ctx)
        guard let h = gd_embed_start(json, cb) else {
            Unmanaged<EventBox>.fromOpaque(ctx).release()
            throw lastError()
        }
        return GaiaDeskEmbed(handle: h, box: box)
    }

    private init(handle: OpaquePointer, box: EventBox) {
        self.handle = handle
        self.box = box
    }

    deinit { stop() }

    /// End the session. Safe to call more than once.
    public func stop() {
        guard let h = handle else { return }
        handle = nil
        gd_embed_stop(h)
    }

    /// Mask these rects: relative to the top-left of the shared window's
    /// frame, in points. Replaces any earlier set.
    public func setMaskedRects(_ rects: [CGRect]) throws {
        guard let h = handle else { return }
        let c = rects.map { GdRect(x: Double($0.origin.x), y: Double($0.origin.y), w: Double($0.size.width), h: Double($0.size.height)) }
        let rc = c.withUnsafeBufferPointer { gd_embed_set_mask_rects(h, $0.baseAddress, $0.count) }
        if rc != 0 { throw GaiaDeskEmbed.lastError() }
    }

    /// Mask these views (password fields, card numbers, …). Call again after
    /// your layout changes.
    @MainActor
    public func setMaskedViews(_ views: [NSView]) throws {
        try setMaskedRects(views.compactMap(GaiaDeskEmbed.rectInWindow))
    }

    /// Pause (or resume) guided input, as the indicator's own button does.
    public func setPaused(_ paused: Bool) {
        guard let h = handle else { return }
        _ = gd_embed_set_paused(h, paused ? 1 : 0)
    }

    /// A view's frame relative to the top-left of its window's frame, in
    /// points: the space mask rects are in.
    @MainActor
    public static func rectInWindow(_ view: NSView) -> CGRect? {
        guard let window = view.window else { return nil }
        let r = view.convert(view.bounds, to: nil)
        return CGRect(x: r.origin.x, y: window.frame.height - r.maxY, width: r.width, height: r.height)
    }

    // MARK: - plumbing

    static func configJSON(_ c: Configuration, consentGranted: Bool) throws -> String {
        var o: [String: Any] = [
            "embed_token": c.embedToken,
            "consent_granted": consentGranted,
            "company": c.company,
            "capture": c.capture.rawValue,
            "guided": c.guided,
            "fps": c.fps,
        ]
        if let s = c.server { o["server"] = s.absoluteString }
        if let w = c.windowNumber { o["window_id"] = w }
        if !c.maskedRects.isEmpty {
            o["masks"] = c.maskedRects.map { ["x": Double($0.origin.x), "y": Double($0.origin.y), "w": Double($0.width), "h": Double($0.height)] }
        }
        let data = try JSONSerialization.data(withJSONObject: o, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    static func lastError() -> GaiaDeskEmbedError {
        let raw = String(cString: gd_embed_last_error())
        guard let d = raw.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else {
            return GaiaDeskEmbedError(code: "unknown", message: raw)
        }
        return GaiaDeskEmbedError(code: o["code"] as? String ?? "unknown", message: o["message"] as? String ?? "")
    }

    /// One event's JSON → an `Event` (nil for a kind this version does not know).
    public static func parse(_ json: String) -> Event? {
        guard let d = json.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let t = o["type"] as? String else { return nil }
        let s = { (k: String) in o[k] as? String }
        switch t {
        case "state": return s("state").map(Event.state)
        case "code": return .code(s("code") ?? "", sessionId: s("session_id") ?? "", mode: s("mode") ?? "view")
        case "joined": return .joined(agent: s("agent"))
        case "left": return .left
        case "control": return .control(allowed: o["allowed"] as? Bool ?? false)
        case "action": return .action(s("action") ?? "", applied: o["applied"] as? Bool ?? false, reason: s("reason"))
        case "error": return .error(code: s("code") ?? "", message: s("message") ?? "")
        case "ended": return .ended(reason: s("reason") ?? "")
        default: return nil
        }
    }
}

/// Holds the app's handler for the C callback's `user_data`.
final class EventBox {
    private let handler: (GaiaDeskEmbed.Event) -> Void
    init(_ handler: @escaping (GaiaDeskEmbed.Event) -> Void) { self.handler = handler }
    func deliver(_ e: GaiaDeskEmbed.Event?) {
        if let e { handler(e) }
    }
}
