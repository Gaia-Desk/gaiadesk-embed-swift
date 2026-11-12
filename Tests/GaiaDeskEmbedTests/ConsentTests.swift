import XCTest
import GaiaDeskEmbedFFI
@testable import GaiaDeskEmbed

/// The consent step (libgaiadesk_embed 0.4.0). Nothing here shows a dialog:
/// only refusals, the embedded-UI receipt and JSON.
final class ConsentTests: XCTestCase {
    let token = "gdemb_" + String(repeating: "ab", count: 32)
    // The library takes at most 64 (a negative CGRect width cannot be sent: CGRect.width is absolute).
    let tooManyMasks = Array(repeating: CGRect(x: 0, y: 0, width: 1, height: 1), count: 65)

    func object(_ json: String) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
    }

    func answer(_ decision: GaiaDeskEmbed.ConsentDecision.Outcome, guided: Bool = false) -> GaiaDeskEmbed.ConsentAnswer {
        .init(decision: decision, choices: .init(guided: guided, shareLogs: false, capture: .window), wording: ["title": "Share with Acme support?", "accept": "Share"], wordingVersion: "acme-1", locale: "en", company: "Acme", capture: .window, appVersion: "2.4.1")
    }

    func testUnsetOptionsAreLeftOut() throws {
        XCTAssertEqual(try GaiaDeskEmbed.encodeJSON(GaiaDeskEmbed.ConsentStepOptions()), "{}")
    }

    func testOptionsUseTheLibrarysKeys() throws {
        let o = GaiaDeskEmbed.ConsentStepOptions(
            company: "Acme", capture: .screen, guided: true, masked: true, brandColor: "#112233", logoPNG: Data([0x89, 0x50]),
            theme: .init(appearance: .dark, accent: "#0f766e", radius: 12, fontFamily: "Inter", buttonStyle: .pill),
            locale: "fr", wording: ["title": "Partager ?"], wordingVersion: "acme-2026-11",
            choices: .init(offerGuided: true, offerLogs: false), privacyURL: URL(string: "https://acme.test/privacy"),
            termsURL: URL(string: "https://acme.test/terms"), timeoutSeconds: 60, preview: false,
            server: URL(string: "https://gaiadesk.net"), embedToken: token, sessionId: "ss_1", appVersion: "2.4.1",
            windowNumber: 42, maskedRects: [CGRect(x: 1, y: 2, width: 3, height: 4)])
        let j = try object(try GaiaDeskEmbed.encodeJSON(o))
        XCTAssertEqual(Set(j.keys), ["company", "capture", "guided", "masked", "brand_color", "logo_png_base64", "theme", "locale", "wording", "wording_version", "choices", "privacy_url", "terms_url", "timeout_seconds", "preview", "server", "embed_token", "session_id", "app_version", "window_id", "masks"])
        XCTAssertEqual(j["capture"] as? String, "screen")
        XCTAssertEqual(j["logo_png_base64"] as? String, "iVA=")
        XCTAssertEqual(j["privacy_url"] as? String, "https://acme.test/privacy")
        XCTAssertEqual(j["theme"] as? [String: AnyHashable], ["appearance": "dark", "accent": "#0f766e", "radius": 12, "font_family": "Inter", "button_style": "pill"])
        XCTAssertEqual(j["choices"] as? [String: Bool], ["offer_guided": true, "offer_logs": false])
        XCTAssertEqual(j["wording"] as? [String: String], ["title": "Partager ?"], "wording keys are the library's, not converted")
        XCTAssertEqual(j["masks"] as? [[String: Double]], [["x": 1, "y": 2, "w": 3, "h": 4]])
    }

    @MainActor
    func testBadOptionsAreBadConfigAndShowNoDialog() {
        for o in [GaiaDeskEmbed.ConsentStepOptions(brandColor: "teal"), .init(theme: .init(radius: 99)), .init(maskedRects: tooManyMasks)] {
            var events: [GaiaDeskEmbed.Event] = []
            XCTAssertThrowsError(try GaiaDeskEmbed.consent(o) { events.append($0) }) { err in
                XCTAssertEqual((err as? GaiaDeskEmbedError)?.code, "bad_config")
            }
            XCTAssertEqual(events, [])
        }
    }

    func testTheDialogIsMainThreadOnly() {
        let done = expectation(description: "background call")
        DispatchQueue.global().async {
            XCTAssertNil(gd_embed_consent(#"{"company":"Acme"}"#, nil, nil))
            XCTAssertEqual(GaiaDeskEmbed.lastError().code, "wrong_thread")
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
    }

    func testPreviewRefusesBadMasks() {
        XCTAssertThrowsError(try GaiaDeskEmbed.preview(.init(maskedRects: tooManyMasks))) { err in
            XCTAssertEqual((err as? GaiaDeskEmbedError)?.code, "bad_config")
        }
    }

    func testAnEmbeddedAcceptanceBecomesAReceiptAndAToken() throws {
        let d = try GaiaDeskEmbed.recordConsent(answer(.accepted, guided: true))
        XCTAssertEqual(d.decision, .accepted)
        XCTAssertEqual(d.choices, .init(guided: true, shareLogs: false, capture: .window))
        XCTAssertTrue(d.consentToken?.hasPrefix("gdc_") ?? false)
        let r = try XCTUnwrap(d.receipt)
        XCTAssertTrue(r.id.hasPrefix("cr_") && r.id.count == 29, r.id)
        XCTAssertEqual(r.decision, "accepted")
        XCTAssertEqual(r.surface, "embedded")
        XCTAssertEqual(r.wordingVersion, "acme-1")
        XCTAssertEqual(r.wordingSha256.count, 64)
        XCTAssertEqual(r.appVersion, "2.4.1")
        XCTAssertEqual(r.os, "macos")
        XCTAssertEqual(r.sdk, "libgaiadesk_embed/\(GaiaDeskEmbed.version)")
    }

    func testAnEmbeddedDeclineHasAReceiptButNoToken() throws {
        let d = try GaiaDeskEmbed.recordConsent(answer(.declined))
        XCTAssertEqual(d.decision, .declined)
        XCTAssertNil(d.consentToken)
        XCTAssertEqual(d.receipt?.decision, "declined")
    }

    func testAnAnswerWhoseCaptureDiffersFromTheChoiceIsRefused() {
        var a = answer(.accepted)
        a.capture = .screen
        XCTAssertThrowsError(try GaiaDeskEmbed.recordConsent(a)) { err in
            XCTAssertNotNil(err as? GaiaDeskEmbedError)
        }
    }

    func testStartTakesTheDecisionsTokenAndReceipt() throws {
        let d = try GaiaDeskEmbed.recordConsent(answer(.accepted))
        var c = GaiaDeskEmbed.Configuration(embedToken: token, company: "Acme", guided: true)
        c.consentToken = d.consentToken
        c.consentReceipt = d.receipt
        let o = try object(try GaiaDeskEmbed.configJSON(c, consentGranted: true))
        XCTAssertEqual(o["consent_token"] as? String, d.consentToken)
        XCTAssertEqual((o["consent_receipt"] as? [String: Any])?["id"] as? String, d.receipt?.id)
        // The library reads the receipt: the customer chose view only, so guided is refused…
        XCTAssertThrowsError(try GaiaDeskEmbed.start(c, consentGranted: true) { _ in }) { err in
            XCTAssertEqual((err as? GaiaDeskEmbedError)?.code, "consent_required")
        }
        // …and so is another capture than the one agreed to.
        c.guided = false
        c.capture = .screen
        XCTAssertThrowsError(try GaiaDeskEmbed.start(c, consentGranted: true) { _ in }) { err in
            XCTAssertEqual((err as? GaiaDeskEmbedError)?.code, "consent_required")
        }
        // start(_:consent:) starts with what the customer chose: their capture, guided only if allowed.
        c.guided = true
        let applied = GaiaDeskEmbed.applying(d, to: c)
        XCTAssertEqual(applied.capture, .window)
        XCTAssertFalse(applied.guided)
        XCTAssertEqual(applied.consentToken, d.consentToken)
        XCTAssertEqual(applied.consentReceipt, d.receipt)
        XCTAssertTrue(GaiaDeskEmbed.applying(try GaiaDeskEmbed.recordConsent(answer(.accepted, guided: true)), to: c).guided)
        let plain = try GaiaDeskEmbed.configJSON(.init(embedToken: token, company: "Acme"), consentGranted: true)
        XCTAssertFalse(plain.contains("consent_token") || plain.contains("consent_receipt"))
    }

    func testADeclineDoesNotStart() throws {
        let d = try GaiaDeskEmbed.recordConsent(answer(.declined))
        XCTAssertThrowsError(try GaiaDeskEmbed.start(.init(embedToken: token, company: "Acme"), consent: d) { _ in }) { err in
            XCTAssertEqual((err as? GaiaDeskEmbedError)?.code, "consent_required")
        }
    }

    func testConsentEventsParse() {
        let ch = GaiaDeskEmbed.ConsentChoices(guided: true, shareLogs: true, capture: .screen)
        XCTAssertEqual(GaiaDeskEmbed.parse(#"{"type":"consent_shown","locale":"fr","wording_version":"acme-1"}"#), .consentShown(locale: "fr", wordingVersion: "acme-1"))
        XCTAssertEqual(GaiaDeskEmbed.parse(#"{"type":"consent_accepted","choices":{"guided":true,"share_logs":true,"capture":"screen"}}"#), .consentAccepted(choices: ch))
        XCTAssertEqual(GaiaDeskEmbed.parse(#"{"type":"consent_declined","reason":"timeout"}"#), .consentDeclined(reason: "timeout"))
        XCTAssertEqual(GaiaDeskEmbed.parse(#"{"type":"ended","reason":"customer_declined"}"#), .ended(reason: "customer_declined"))
        XCTAssertEqual(GaiaDeskEmbed.parse(#"{"type":"ended","reason":"consent_timeout"}"#), .ended(reason: "consent_timeout"))
    }

    func testTheWaitingStateBringsTheSessionsChoices() {
        XCTAssertEqual(GaiaDeskEmbed.events(#"{"type":"state","state":"waiting","choices":{"guided":false,"share_logs":true,"capture":"window"}}"#),
                       [.state("waiting"), .choices(.init(guided: false, shareLogs: true, capture: .window))])
        XCTAssertEqual(GaiaDeskEmbed.events(#"{"type":"state","state":"waiting"}"#), [.state("waiting")])
        XCTAssertEqual(GaiaDeskEmbed.events(#"{"type":"future_thing"}"#), [])
    }

    func testTheDecisionDecodes() throws {
        let d = try JSONDecoder().decode(GaiaDeskEmbed.ConsentDecision.self, from: Data(#"{"decision":"unavailable"}"#.utf8))
        XCTAssertEqual(d, .init(decision: .unavailable, choices: nil, consentToken: nil, receipt: nil))
    }
}
