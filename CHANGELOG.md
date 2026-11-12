# Changelog

## 0.3.0

- libgaiadesk_embed 0.3.0: the consent dialog and indicator attach to the calling window.
  `Configuration.parentWindow` / `ConsentOptions.parentWindow` (`NSWindow`, default: your app's
  focused window) make the dialog a sheet on it and keep the indicator clear of it.
- `Configuration.indicatorPosition` (a corner) and `Configuration.indicatorOrigin` (a place you
  kept from the new `.indicatorMoved(x:y:)` event) set where the indicator appears.
- `ConsentOptions.masked`: the dialog says private fields stay hidden.
- New ended reason `customer_cancelled`: Cancel on the indicator, or `stop()`, before an agent was
  admitted. `Event` gains a case, so an exhaustive `switch` over it needs `.indicatorMoved`.

## 0.2.0

- libgaiadesk_embed 0.2.0: white-label branding. `Configuration.brandColor` (`#RRGGBB`) and
  `Configuration.logoPNG` (PNG `Data`, at most 256 KiB) put your colour and logo on the
  "Sharing with <company>" indicator; `requestConsent(_: ConsentOptions)` (the library's
  `gd_embed_show_consent_ex`) shows the consent dialog in your look. A colour that is not
  `#RRGGBB` throws `GaiaDeskEmbedError` (`bad_config`) before the native call; a colour or logo
  the library refuses throws `bad_config` instead of reading as a decline.
- No customer-visible text names GaiaDesk any more (connect errors).

## 0.1.0

- `GaiaDeskEmbed`: share your Mac app's window with your support team from a "Get help" button —
  consent enforced by the library, its own "Sharing with … · Stop sharing" indicator, masked views,
  view-only by default with an opt-in guided mode delivered inside your process.
- `HelpDeskDemo`: an AppKit example.
