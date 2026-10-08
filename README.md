# GaiaDeskEmbed (Swift, macOS)

A **"Get help" button for your Mac app**. Your customer clicks it and agrees; **your app's window**
is shared with **your** support team, who see it in the GaiaDesk console's Support page and, if you
allow it, guide it: click and type **inside your app only**.

- Swift Package wrapping `libgaiadesk_embed` (a prebuilt universal XCFramework, Apple silicon and
  Intel, macOS 12.3+).
- **Consent first**: the library refuses to start until your user has agreed. Use its native
  consent dialog or your own.
- Shares **your app's own window** by default (ScreenCaptureKit window capture). Your app's other
  windows, other apps and the desktop are never in the picture unless you opt into `.app` or
  `.screen`.
- A visible **"Sharing with Acme · Stop sharing"** panel, drawn by the library, for as long as
  anything is shared. Frames only leave while it is on screen.
- **Mask** password fields, card numbers, anything: they are painted black before a frame is
  encoded.
- **View-only by default.** Guided mode delivers clicks and typing *inside your process* (to your own
  windows, never through the system's input stream), only while your app is in front, and your
  customer can pause it.
- No install, no service, nothing written to disk: the session ends when your app calls `stop()`
  or quits.

## Install

```swift
// Package.swift
.package(url: "https://github.com/Gaia-Desk/gaiadesk-embed-swift.git", from: "0.1.0"),
// target:
.product(name: "GaiaDeskEmbed", package: "gaiadesk-embed-swift"),
```

SwiftPM downloads the native library (`GaiaDeskEmbedFFI.xcframework`) from this repository's
release and checks it against the checksum in `Package.swift`. To build against a local copy
(`scripts/fetch-binary.sh 0.1.0` puts the release's in `Frameworks/`), set
`GAIADESK_EMBED_LOCAL_BINARY=1`. Your app needs the **Screen Recording** permission (`NSScreenCaptureUsageDescription`
is not required, but macOS asks the user the first time).

## Quick start

Your backend creates a support session with a secret API key (scope `support`) and hands the app
its `embed_token`; the session's `mode` (`view` or `cobrowse`) is your backend's choice:

```sh
curl -s -X POST https://api.gaiadesk.net/v1/support/sessions \
  -H "Authorization: Bearer $GAIADESK_API_KEY" -H "Content-Type: application/json" \
  -d '{"mode": "view", "customer": {"name": "Ada", "plan": "pro"}}'
# → {"id": "ss_…", "join_code": "123456789", "embed_token": "gdemb_…", …}
```

(A native app uses a token from its backend, never a publishable key: a key in a shipped binary is
anyone's.)

```swift
import GaiaDeskEmbed

@MainActor func getHelp(token: String, window: NSWindow) {
    guard GaiaDeskEmbed.requestConsent(company: "Acme") == true else { return }
    do {
        let help = try GaiaDeskEmbed.start(
            .init(embedToken: token, company: "Acme", windowNumber: window.windowNumber),
            consentGranted: true
        ) { event in
            switch event {
            case let .code(code, _, _): print("support code", code)   // read it to the agent
            case let .joined(agent): print(agent ?? "an agent", "is viewing")
            case let .ended(reason): print("ended:", reason)
            default: break
            }
        }
        try help.setMaskedViews([cardNumberField, passwordField])
        self.help = help
    } catch let e as GaiaDeskEmbedError {
        print("could not start:", e.code, e.message)
    } catch {}
}
```

Your support team opens **Support** in the GaiaDesk console, sees the waiting customer and joins
(or types the nine-digit code).

### Configuration

| Field | |
|---|---|
| `embedToken` | `gdemb_…`, from your backend |
| `company` | shown on the consent dialog and the indicator |
| `server` | default `https://gaiadesk.net` |
| `capture` | `.window` (default: `windowNumber`, or your frontmost window), `.app` (every window of your app), `.screen` (the whole display — opt-in) |
| `guided` | `false` (default). `true` allows guided input in a `cobrowse` session |
| `fps` | 1–30 (default 15) |
| `maskedRects` | regions painted out from the first frame (see Masking) |

### Masking

Pass the regions you already know in `maskedRects` when you start (`rectInWindow(_:)` turns a
view into one): an agent can join straight away, and only start-time masks are guaranteed to
cover the first frame. Afterwards, `setMaskedViews(_:)` takes views; `setMaskedRects(_:)` takes rects relative to the top-left of the
shared window's frame, in points. Call again when your layout changes. If the window cannot be
located, the whole picture is painted out rather than risk a leak.

### Guided mode

Only when your app passes `guided: true` **and** your backend created the session as `cobrowse`.
Then the agent's clicks, scrolling and typing are delivered to your app's own windows, inside your
process, and only while your app is the active app; a click outside your windows, on the indicator
or on a masked view is refused. Your customer pauses it with **Pause control** on the indicator
(or you call `setPaused(true)`). Highlights are not supported natively.

### Events

| Event | |
|---|---|
| `.state(s)` | `starting`, `waiting`, `connected`, `ended` |
| `.code(code, sessionId:, mode:)` | registered; `code` is what the agent joins with |
| `.joined(agent:)` / `.left` | an agent joined / left |
| `.control(allowed:)` | guided input paused or resumed |
| `.action(_, applied:, reason:)` | a guided request and its outcome |
| `.error(code:, message:)` | e.g. `capture_failed`, `connect_failed`, `indicator_unavailable` |
| `.ended(reason:)` | `stopped` (the customer), `app_stopped`, `disconnected`, `expired`, `error` — always last |

Events arrive on the main queue.

## Example

`Examples/HelpDeskDemo` is a small AppKit app with a Get help button and a masked card number:

```sh
GAIADESK_EMBED_TOKEN=gdemb_… swift run HelpDeskDemo
```

## Licence

The Swift sources here are MIT (`LICENSE`). The prebuilt `libgaiadesk_embed` binary is licensed
under the GaiaDesk Native Binary Licence (`LICENSE-BINARY`): free to use in your apps, linked into
them, unmodified.
