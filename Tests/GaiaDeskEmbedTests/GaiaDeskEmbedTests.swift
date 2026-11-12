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
        XCTAssertNil(o["masks"], "no masks key unless the app names some")
    }

    func testMasksGoInTheStartConfig() throws {
        let c = GaiaDeskEmbed.Configuration(embedToken: token, company: "Acme", maskedRects: [CGRect(x: 10, y: 20, width: 100, height: 30)])
        let json = try GaiaDeskEmbed.configJSON(c, consentGranted: true)
        let o = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        let masks = o["masks"] as! [[String: Double]]
        XCTAssertEqual(masks, [["x": 10, "y": 20, "w": 100, "h": 30]])
    }

    func testBrandKeysGoInTheStartConfigOnlyWhenSet() throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let c = GaiaDeskEmbed.Configuration(embedToken: token, company: "Acme", brandColor: "#0f766E", logoPNG: png)
        let o = try JSONSerialization.jsonObject(with: Data(try GaiaDeskEmbed.configJSON(c, consentGranted: true).utf8)) as! [String: Any]
        XCTAssertEqual(o["brand_color"] as? String, "#0f766E")
        XCTAssertEqual(o["logo_png_base64"] as? String, "iVBORw0KGgo=")
        let plain = try GaiaDeskEmbed.configJSON(.init(embedToken: token, company: "Acme", logoPNG: Data()), consentGranted: true)
        XCTAssertFalse(plain.contains("brand_") || plain.contains("logo_"))
    }

    func testAColourThatIsNotRRGGBBIsBadConfig() {
        for bad in ["0f766e", "#0f766", "#0f766eff", "teal", "#gggggg", "", "#0f766é"] {
            XCTAssertThrowsError(try GaiaDeskEmbed.configJSON(.init(embedToken: token, company: "Acme", brandColor: bad), consentGranted: true), bad) { err in
                XCTAssertEqual((err as? GaiaDeskEmbedError)?.code, "bad_config")
            }
            XCTAssertThrowsError(try GaiaDeskEmbed.consentJSON(.init(company: "Acme", brandColor: bad)), bad)
        }
    }

    func testConsentOptionsJSON() throws {
        XCTAssertEqual(try GaiaDeskEmbed.consentJSON(.init(company: "")), #"{"capture":"window","guided":false}"#)
        let c = GaiaDeskEmbed.ConsentOptions(company: "Acme", capture: .screen, guided: true, brandColor: "#112233", logoPNG: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        XCTAssertEqual(try GaiaDeskEmbed.consentJSON(c), ##"{"brand_color":"#112233","capture":"screen","company":"Acme","guided":true,"logo_png_base64":"iVBORw0KGgo="}"##)
    }

    @MainActor
    func testParentWindowAndIndicatorPlaceGoInTheStartConfigOnlyWhenSet() throws {
        let w = NSWindow(contentRect: .init(x: 0, y: 0, width: 10, height: 10), styleMask: [], backing: .buffered, defer: true)
        let c = GaiaDeskEmbed.Configuration(embedToken: token, company: "Acme", parentWindow: w, indicatorPosition: .bottomLeft, indicatorOrigin: CGPoint(x: 120, y: 48.5))
        let o = try JSONSerialization.jsonObject(with: Data(try GaiaDeskEmbed.configJSON(c, consentGranted: true).utf8)) as! [String: Any]
        XCTAssertEqual(o["parent_window"] as? Int, Int(bitPattern: Unmanaged.passUnretained(w).toOpaque()))
        XCTAssertEqual(o["indicator_position"] as? String, "bottom-left")
        XCTAssertEqual(o["indicator_origin"] as? [String: Double], ["x": 120, "y": 48.5])
        let plain = try GaiaDeskEmbed.configJSON(.init(embedToken: token, company: "Acme"), consentGranted: true)
        XCTAssertFalse(plain.contains("parent_window") || plain.contains("indicator_"))
        XCTAssertEqual(GaiaDeskEmbed.IndicatorPosition.topRight.rawValue, "top-right")
    }

    @MainActor
    func testConsentMaskedAndParentWindow() throws {
        let w = NSWindow(contentRect: .init(x: 0, y: 0, width: 10, height: 10), styleMask: [], backing: .buffered, defer: true)
        let ptr = Int(bitPattern: Unmanaged.passUnretained(w).toOpaque())
        XCTAssertEqual(try GaiaDeskEmbed.consentJSON(.init(company: "Acme", masked: true, parentWindow: w)), #"{"capture":"window","company":"Acme","guided":false,"masked":true,"parent_window":\#(ptr)}"#)
    }

    @MainActor
    func testARefusedLogoIsAnErrorNotADecline() {
        // Not a PNG: the library refuses before any dialog is shown.
        XCTAssertThrowsError(try GaiaDeskEmbed.requestConsent(.init(company: "Acme", logoPNG: Data("GIF89a".utf8)))) { err in
            XCTAssertEqual((err as? GaiaDeskEmbedError)?.code, "bad_config")
        }
    }

    func testEventsParse() {
        XCTAssertEqual(GaiaDeskEmbed.parse(#"{"type":"code","code":"123456789","session_id":"ss_1","mode":"view"}"#), .code("123456789", sessionId: "ss_1", mode: "view"))
        XCTAssertEqual(GaiaDeskEmbed.parse(#"{"type":"action","action":"click","applied":false,"reason":"view_only"}"#), .action("click", applied: false, reason: "view_only"))
        XCTAssertEqual(GaiaDeskEmbed.parse(#"{"type":"ended","reason":"stopped"}"#), .ended(reason: "stopped"))
        XCTAssertEqual(GaiaDeskEmbed.parse(#"{"type":"ended","reason":"customer_cancelled"}"#), .ended(reason: "customer_cancelled"))
        XCTAssertEqual(GaiaDeskEmbed.parse(#"{"type":"indicator_moved","x":812,"y":40.5}"#), .indicatorMoved(x: 812, y: 40.5))
        XCTAssertNil(GaiaDeskEmbed.parse(#"{"type":"indicator_moved"}"#))
        XCTAssertNil(GaiaDeskEmbed.parse(#"{"type":"future_thing"}"#))
    }

    func testTheBinaryIdentifiesItself() {
        XCTAssertFalse(GaiaDeskEmbed.version.isEmpty)
        XCTAssertTrue(GaiaDeskEmbed.buildInfo.contains("\"os\":\"macos\""))
    }
}
