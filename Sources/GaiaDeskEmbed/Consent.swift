// The consent step (libgaiadesk_embed 0.4.0, GD-31): the library's own
// dialog with a live preview of what support will see, per-session choices,
// localized wording, and a consent receipt the library makes and stores.

import AppKit
import Foundation
import GaiaDeskEmbedFFI

extension GaiaDeskEmbed.Capture: Codable {}

extension GaiaDeskEmbed {
    /// The consent dialog's look (`ConsentStepOptions.theme`). Every field optional.
    public struct ConsentTheme: Codable, Equatable, Sendable {
        public enum Appearance: String, Codable, Sendable { case auto, light, dark }
        public enum ButtonStyle: String, Codable, Sendable { case filled, outline, pill }
        public var appearance: Appearance?
        /// `"#RRGGBB"` colours.
        public var background: String?
        public var surface: String?
        public var text: String?
        public var accent: String?
        /// Corner radius in points, 0 to 24.
        public var radius: Int?
        /// A font family name; falls back to the system UI font.
        public var fontFamily: String?
        public var buttonStyle: ButtonStyle?

        public init(appearance: Appearance? = nil, background: String? = nil, surface: String? = nil, text: String? = nil, accent: String? = nil, radius: Int? = nil, fontFamily: String? = nil, buttonStyle: ButtonStyle? = nil) {
            self.appearance = appearance
            self.background = background
            self.surface = surface
            self.text = text
            self.accent = accent
            self.radius = radius
            self.fontFamily = fontFamily
            self.buttonStyle = buttonStyle
        }

        enum CodingKeys: String, CodingKey {
            case appearance, background, surface, text, accent, radius
            case fontFamily = "font_family", buttonStyle = "button_style"
        }
    }

    /// What the customer may choose in the dialog (`ConsentStepOptions.choices`).
    public struct ConsentOffers: Codable, Equatable, Sendable {
        /// "Allow support to click and type" (only when the app asks for `guided`).
        public var offerGuided: Bool?
        /// "Also share app logs".
        public var offerLogs: Bool?
        /// One window or the whole screen (only where both are allowed).
        public var offerCapture: Bool?

        public init(offerGuided: Bool? = nil, offerLogs: Bool? = nil, offerCapture: Bool? = nil) {
            self.offerGuided = offerGuided
            self.offerLogs = offerLogs
            self.offerCapture = offerCapture
        }

        enum CodingKeys: String, CodingKey {
            case offerGuided = "offer_guided", offerLogs = "offer_logs", offerCapture = "offer_capture"
        }
    }

    /// The consent step's options (`consent(_:)`, `preview(_:)`). Every field
    /// optional; unset ones are left out and take the library's default.
    public struct ConsentStepOptions: Encodable {
        /// `{company}` in the wording.
        public var company: String?
        /// What is shared by default.
        public var capture: Capture?
        /// The app wants click-and-type (the customer may still say no).
        public var guided: Bool?
        /// Say private fields stay hidden (pass `maskedRects` too).
        public var masked: Bool?
        public var brandColor: String?
        /// PNG bytes (at most 256 KiB).
        public var logoPNG: Data?
        /// The dialog is a sheet on this window.
        public var parentWindow: NSWindow?
        public var theme: ConsentTheme?
        /// `"auto"` (the system's languages) or a BCP-47 tag.
        public var locale: String?
        /// Per-key overrides of the default wording (`title`, `accept`, …;
        /// placeholders `{company}` `{team}` `{minutes}` `{count}`).
        public var wording: [String: String]?
        /// Your id for your wording; default `gaiadesk-<version>-<locale>`.
        public var wordingVersion: String?
        public var choices: ConsentOffers?
        /// https only; shown as links.
        public var privacyURL: URL?
        public var termsURL: URL?
        /// 0 never; else the dialog declines itself (decision `.timeout`).
        public var timeoutSeconds: Int?
        /// The live preview (default on, when capture is possible).
        public var preview: Bool?
        /// With `embedToken` (and `sessionId`): the library posts the receipt
        /// to the session itself and shows who is waiting.
        public var server: URL?
        public var embedToken: String?
        public var sessionId: String?
        /// Into the receipt; default the app bundle's version.
        public var appVersion: String?
        /// The preview's target and masks, as `Configuration`.
        public var windowNumber: Int?
        public var maskedRects: [CGRect]?

        public init(company: String? = nil, capture: Capture? = nil, guided: Bool? = nil, masked: Bool? = nil, brandColor: String? = nil, logoPNG: Data? = nil, parentWindow: NSWindow? = nil, theme: ConsentTheme? = nil, locale: String? = nil, wording: [String: String]? = nil, wordingVersion: String? = nil, choices: ConsentOffers? = nil, privacyURL: URL? = nil, termsURL: URL? = nil, timeoutSeconds: Int? = nil, preview: Bool? = nil, server: URL? = nil, embedToken: String? = nil, sessionId: String? = nil, appVersion: String? = nil, windowNumber: Int? = nil, maskedRects: [CGRect]? = nil) {
            self.company = company
            self.capture = capture
            self.guided = guided
            self.masked = masked
            self.brandColor = brandColor
            self.logoPNG = logoPNG
            self.parentWindow = parentWindow
            self.theme = theme
            self.locale = locale
            self.wording = wording
            self.wordingVersion = wordingVersion
            self.choices = choices
            self.privacyURL = privacyURL
            self.termsURL = termsURL
            self.timeoutSeconds = timeoutSeconds
            self.preview = preview
            self.server = server
            self.embedToken = embedToken
            self.sessionId = sessionId
            self.appVersion = appVersion
            self.windowNumber = windowNumber
            self.maskedRects = maskedRects
        }

        enum CodingKeys: String, CodingKey {
            case company, capture, guided, masked, theme, locale, wording, choices, preview, server, masks
            case brandColor = "brand_color", logoPNG = "logo_png_base64", parentWindow = "parent_window"
            case wordingVersion = "wording_version", privacyURL = "privacy_url", termsURL = "terms_url"
            case timeoutSeconds = "timeout_seconds", embedToken = "embed_token", sessionId = "session_id"
            case appVersion = "app_version", windowNumber = "window_id"
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encodeIfPresent(company, forKey: .company)
            try c.encodeIfPresent(capture, forKey: .capture)
            try c.encodeIfPresent(guided, forKey: .guided)
            try c.encodeIfPresent(masked, forKey: .masked)
            try c.encodeIfPresent(brandColor, forKey: .brandColor)
            if let logoPNG, !logoPNG.isEmpty { try c.encode(logoPNG.base64EncodedString(), forKey: .logoPNG) }
            try c.encodeIfPresent(parentWindow.map { Int(bitPattern: Unmanaged.passUnretained($0).toOpaque()) }, forKey: .parentWindow)
            try c.encodeIfPresent(theme, forKey: .theme)
            try c.encodeIfPresent(locale, forKey: .locale)
            try c.encodeIfPresent(wording, forKey: .wording)
            try c.encodeIfPresent(wordingVersion, forKey: .wordingVersion)
            try c.encodeIfPresent(choices, forKey: .choices)
            try c.encodeIfPresent(privacyURL?.absoluteString, forKey: .privacyURL)
            try c.encodeIfPresent(termsURL?.absoluteString, forKey: .termsURL)
            try c.encodeIfPresent(timeoutSeconds, forKey: .timeoutSeconds)
            try c.encodeIfPresent(preview, forKey: .preview)
            try c.encodeIfPresent(server?.absoluteString, forKey: .server)
            try c.encodeIfPresent(embedToken, forKey: .embedToken)
            try c.encodeIfPresent(sessionId, forKey: .sessionId)
            try c.encodeIfPresent(appVersion, forKey: .appVersion)
            try c.encodeIfPresent(windowNumber, forKey: .windowNumber)
            try c.encodeIfPresent(maskedRects.map { $0.map(GaiaDeskEmbed.maskJSON) }, forKey: .masks)
        }
    }

    /// What the customer chose (and the session then runs with).
    public struct ConsentChoices: Codable, Equatable, Sendable {
        public var guided: Bool
        public var shareLogs: Bool
        public var capture: Capture

        public init(guided: Bool = false, shareLogs: Bool = false, capture: Capture = .window) {
            self.guided = guided
            self.shareLogs = shareLogs
            self.capture = capture
        }

        enum CodingKeys: String, CodingKey {
            case guided, capture
            case shareLogs = "share_logs"
        }
    }

    /// The library's record of the answer: store it, or let the library post
    /// it to the session (`server` + `embedToken`), or pass it to `start`.
    public struct ConsentReceipt: Codable, Equatable, Sendable {
        /// `cr_…`
        public var id: String
        /// `accepted`, `declined` or `timeout`.
        public var decision: String
        /// RFC 3339, UTC, milliseconds.
        public var at: String
        /// `native_dialog` or `embedded` (your own UI, or the web component).
        public var surface: String
        public var locale: String
        public var wordingVersion: String
        /// SHA-256 of the strings actually shown.
        public var wordingSha256: String
        public var choices: ConsentChoices
        /// The login name (never a full name or path).
        public var osUser: String?
        public var os: String
        public var appName: String?
        public var appVersion: String?
        /// `libgaiadesk_embed/<version>`.
        public var sdk: String

        enum CodingKeys: String, CodingKey {
            case id, decision, at, surface, locale, choices, os, sdk
            case wordingVersion = "wording_version", wordingSha256 = "wording_sha256", osUser = "os_user"
            case appName = "app_name", appVersion = "app_version"
        }
    }

    /// The consent step's answer.
    public struct ConsentDecision: Codable, Equatable, Sendable {
        public enum Outcome: String, Codable, Sendable {
            case accepted, declined, timeout
            /// No dialog here: ask with your own UI, then `recordConsent(_:)`.
            case unavailable
        }
        public var decision: Outcome
        /// nil when `.unavailable`.
        public var choices: ConsentChoices?
        /// `.accepted` only: for `Configuration.consentToken` (`start(_:consent:onEvent:)` sets it).
        public var consentToken: String?
        /// Every outcome but `.unavailable`.
        public var receipt: ConsentReceipt?

        enum CodingKeys: String, CodingKey {
            case decision, choices, receipt
            case consentToken = "consent_token"
        }
    }

    /// Your own (or an embedded) consent UI's answer, for `recordConsent(_:)`.
    public struct ConsentAnswer: Encodable {
        /// `.accepted`, `.declined` or `.timeout`.
        public var decision: ConsentDecision.Outcome
        public var choices: ConsentChoices
        /// The strings your UI showed, by key (`title`, `accept`, …): hashed into the receipt.
        public var wording: [String: String]
        public var wordingVersion: String?
        public var locale: String?
        public var company: String?
        /// Must equal `choices.capture` when set.
        public var capture: Capture?
        public var appVersion: String?
        /// With `embedToken` (and `sessionId`): the library posts the receipt too.
        public var server: URL?
        public var embedToken: String?
        public var sessionId: String?

        public init(decision: ConsentDecision.Outcome, choices: ConsentChoices, wording: [String: String], wordingVersion: String? = nil, locale: String? = nil, company: String? = nil, capture: Capture? = nil, appVersion: String? = nil, server: URL? = nil, embedToken: String? = nil, sessionId: String? = nil) {
            self.decision = decision
            self.choices = choices
            self.wording = wording
            self.wordingVersion = wordingVersion
            self.locale = locale
            self.company = company
            self.capture = capture
            self.appVersion = appVersion
            self.server = server
            self.embedToken = embedToken
            self.sessionId = sessionId
        }

        enum CodingKeys: String, CodingKey {
            case decision, choices, wording, locale, company, capture, server
            case wordingVersion = "wording_version", appVersion = "app_version", embedToken = "embed_token", sessionId = "session_id"
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(decision, forKey: .decision)
            try c.encode(choices, forKey: .choices)
            try c.encode(wording, forKey: .wording)
            try c.encodeIfPresent(wordingVersion, forKey: .wordingVersion)
            try c.encodeIfPresent(locale, forKey: .locale)
            try c.encodeIfPresent(company, forKey: .company)
            try c.encodeIfPresent(capture, forKey: .capture)
            try c.encodeIfPresent(appVersion, forKey: .appVersion)
            try c.encodeIfPresent(server?.absoluteString, forKey: .server)
            try c.encodeIfPresent(embedToken, forKey: .embedToken)
            try c.encodeIfPresent(sessionId, forKey: .sessionId)
        }
    }

    /// One frame of exactly what support would see (masks filled black),
    /// at most 480×300.
    public struct ConsentPreview: Equatable, Sendable {
        public var png: Data
        public var width: Int
        public var height: Int
        public var maskedCount: Int
    }

    /// The consent step: the library's dialog with a live preview of what
    /// support will see, the customer's choices and localized wording. Blocks
    /// (modal) until answered. `onEvent` gets `.consentShown`,
    /// `.consentAccepted` / `.consentDeclined` before this returns. Throws
    /// `bad_config` for refused options, `wrong_thread` off the main thread.
    @MainActor
    public static func consent(_ options: ConsentStepOptions = .init(), onEvent: ((Event) -> Void)? = nil) throws -> ConsentDecision {
        let json = try encodeJSON(options)
        let box = EventBox(onEvent ?? { _ in })
        // Events arrive on this thread, before gd_embed_consent returns.
        let cb: GdEventFn = { userData, eventJSON in
            guard let userData, let eventJSON else { return }
            let box = Unmanaged<EventBox>.fromOpaque(userData).takeUnretainedValue()
            GaiaDeskEmbed.events(String(cString: eventJSON)).forEach(box.deliver)
        }
        let raw: UnsafePointer<CChar>? = withExtendedLifetime(box) {
            gd_embed_consent(json, onEvent == nil ? nil : cb, Unmanaged.passUnretained(box).toOpaque())
        }
        return try decodeDecision(raw)
    }

    /// One frame of what support would see. Reads `capture`, `windowNumber`,
    /// `parentWindow` and `maskedRects`. Throws `capture_unavailable` (no
    /// Screen Recording permission, no window).
    public static func preview(_ options: ConsentStepOptions = .init()) throws -> ConsentPreview {
        let only = ConsentStepOptions(capture: options.capture, parentWindow: options.parentWindow, windowNumber: options.windowNumber, maskedRects: options.maskedRects)
        guard let raw = gd_embed_preview(try encodeJSON(only)) else { throw lastError() }
        struct Wire: Decodable { let png_base64: String; let width: Int; let height: Int; let masked_count: Int }
        let w = try JSONDecoder().decode(Wire.self, from: Data(String(cString: raw).utf8))
        return ConsentPreview(png: Data(base64Encoded: w.png_base64) ?? Data(), width: w.width, height: w.height, maskedCount: w.masked_count)
    }

    /// Your own (or an embedded) consent UI's answer, made a receipt by the
    /// library (`surface` `embedded`). An `.accepted` answer carries a
    /// `consentToken` for `start`.
    public static func recordConsent(_ answer: ConsentAnswer) throws -> ConsentDecision {
        try decodeDecision(gd_embed_record_consent_ex(try encodeJSON(answer)))
    }

    /// `start` after the consent step: the decision's token and receipt go
    /// with the join, `capture` becomes what the customer chose and `guided`
    /// stays on only if they allowed it. Anything but `.accepted` is refused
    /// (`consent_required`) by the library.
    public static func start(_ config: Configuration, consent: ConsentDecision, onEvent: @escaping (Event) -> Void) throws -> GaiaDeskEmbed {
        try start(applying(consent, to: config), consentGranted: consent.decision == .accepted, onEvent: onEvent)
    }

    /// `config` as `start(_:consent:onEvent:)` starts it. Pure.
    static func applying(_ consent: ConsentDecision, to config: Configuration) -> Configuration {
        var c = config
        c.consentToken = consent.consentToken
        c.consentReceipt = consent.receipt
        if let ch = consent.choices {
            c.capture = ch.capture
            c.guided = c.guided && ch.guided
        }
        return c
    }

    // MARK: - plumbing

    static func maskJSON(_ r: CGRect) -> [String: Double] {
        ["x": Double(r.origin.x), "y": Double(r.origin.y), "w": Double(r.width), "h": Double(r.height)]
    }

    static func encodeJSON<T: Encodable>(_ v: T) throws -> String {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try e.encode(v), as: UTF8.self)
    }

    static func decodeDecision(_ raw: UnsafePointer<CChar>?) throws -> ConsentDecision {
        guard let raw else { throw lastError() }
        return try JSONDecoder().decode(ConsentDecision.self, from: Data(String(cString: raw).utf8))
    }

    static func parseChoices(_ o: Any?) -> ConsentChoices? {
        guard let o = o as? [String: Any], let d = try? JSONSerialization.data(withJSONObject: o) else { return nil }
        return try? JSONDecoder().decode(ConsentChoices.self, from: d)
    }
}
