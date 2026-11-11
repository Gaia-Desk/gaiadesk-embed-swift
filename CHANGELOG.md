# Changelog

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
