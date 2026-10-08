import XCTest
@testable import GaiaDeskEmbed

final class GaiaDeskEmbedTests: XCTestCase {
    let token = "gdemb_" + String(repeating: "ab", count: 32)

    func testTheLibraryRefusesToStartWithoutConsent() {
        let config = GaiaDeskEmbed.Configuration(embedToken: token, company: "Acme")
        XCTAssertThrowsError(try GaiaDeskEmbed.start(config, consentGranted: false) { _ in }) { err in
            XCTAssertEqual((err as? GaiaDeskEmbedError)?.code, "consent_required")
        }
    }

    func testABadTokenIsRefusedBeforeAnythingStarts() {
        let config = GaiaDeskEmbed.Configuration(embedToken: "gdk_live_secret", company: "Acme")
        XCTAssertThrowsError(try GaiaDeskEmbed.start(config, consentGranted: true) { _ in }) { err in
            XCTAssertEqual((err as? GaiaDeskEmbedError)?.code, "bad_token")
        }
    }

    func testConfigurationJSON() throws {
        var c = GaiaDeskEmbed.Configuration(embedToken: token, company: "Acme", capture: .screen, windowNumber: 42, guided: true)
        c.server = URL(string: "http://127.0.0.1:9000")
        let json = try GaiaDeskEmbed.configJSON(c, consentGranted: true)
        let o = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        XCTAssertEqual(o["consent_granted"] as? Bool, true)
        XCTAssertEqual(o["capture"] as? String, "screen")
        XCTAssertEqual(o["window_id"] as? Int, 42)
        XCTAssertEqual(o["guided"] as? Bool, true)
        XCTAssertEqual(o["server"] as? String, "http://127.0.0.1:9000")
    }

    func testDefaultsAreViewOnlyAndTheAppsWindow() throws {
        let json = try GaiaDeskEmbed.configJSON(.init(embedToken: token, company: "Acme"), consentGranted: true)
        let o = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        XCTAssertEqual(o["capture"] as? String, "window")
        XCTAssertEqual(o["guided"] as? Bool, false)
    }

    func testEventsParse() {
        XCTAssertEqual(GaiaDeskEmbed.parse(#"{"type":"code","code":"123456789","session_id":"ss_1","mode":"view"}"#), .code("123456789", sessionId: "ss_1", mode: "view"))
        XCTAssertEqual(GaiaDeskEmbed.parse(#"{"type":"action","action":"click","applied":false,"reason":"view_only"}"#), .action("click", applied: false, reason: "view_only"))
        XCTAssertEqual(GaiaDeskEmbed.parse(#"{"type":"ended","reason":"stopped"}"#), .ended(reason: "stopped"))
        XCTAssertNil(GaiaDeskEmbed.parse(#"{"type":"future_thing"}"#))
    }

    func testTheBinaryIdentifiesItself() {
        XCTAssertFalse(GaiaDeskEmbed.version.isEmpty)
        XCTAssertTrue(GaiaDeskEmbed.buildInfo.contains("\"os\":\"macos\""))
    }
}
