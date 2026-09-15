# BidMachine AdLoader example

Reproduces the banner integration The Weather Channel uses on iOS: a Google Ad Manager
`AdLoader` request with the Ad Manager banner and native ad types, no `BannerView`, and the
banner sizes supplied only through `validBannerSizes(for:)`.

Google collects bidding signals before it asks the delegate for sizes, so the BidMachine adapter
sees an invalid ad size during signal collection. Adapter 3.7.2.0 turned that into an adaptive
placement of width 0; the BidMachine SDK holds bid payloads to the requested width, so every
payload was rejected on the device and the banner never rendered. Adapter 3.7.3.0 requests the
screen width instead.

At load time Google hands the adapter the unit's primary size (240x133 here) whatever size the
bid declared, and the SDK holds the payload to that load request. A creative wider than the
primary size, such as 320x100, would be refused, so 3.7.3.0 loads with the screen width and the
height left open: any payload that fits the screen loads, laid out in the view Google provides.

## Choosing the sizes

The Sizes button in the navigation bar picks what `validBannerSizes(for:)` answers, and reloads.
The first entry is the primary size: Google puts it on the bid request and sizes the adapter's
load request from it, whatever the bid declares. The presets cover the Weather Channel feed list
with 240x133 first, the same list led by 320x50 or 300x250, a single 320x50 or 300x250, and an
anchored or inline adaptive banner at the screen width. The console line
`validBannerSizes asked; returning N sizes: …` shows what each load offered, and the status label
names the active preset. A launch argument picks the preset without the UI, for example
`xcrun simctl launch <udid> <bundle id> -sizes bannerOnly`; the names are the `SizeSet` cases:
`weatherFeed`, `bannerFirst`, `mrecFirst`, `bannerOnly`, `mrecOnly`, `anchoredAdaptive`,
`inlineAdaptive`.

## Setup

The project depends on the repository's Swift package, so the adapter is built from the sources
in `adapters/BidMachine/BidMachineAdapter` and pinned to Google Mobile Ads 13.0.0 and BidMachine
SDK 3.7.2 exactly as publishers consume it.

1. Open `BidMachineAdLoaderExample.xcodeproj` and let Xcode resolve the packages.
2. The target's `GAD_APPLICATION_IDENTIFIER` build setting is the publisher's Ad Manager app ID
   and `adUnitID` in `AdLoaderBannerViewController.swift` is their feed unit, taken from the
   app's Google publisher settings (`getconfig/pubsetting`), so Google applies the same mediation
   configuration: the unit is registered as a banner unit with BidMachine as an SDK bidder and as
   a native unit without it. Swap both to test another publisher.
3. Run on a device whose IDFA is allowlisted for BidMachine test bidders. The app asks for
   tracking authorization before its first request and prints the IDFA to the console
   (`tracking authorization 3, IDFA …`); allow it, and use that IDFA for the allowlist and for the
   exchange's per-IFA logging allocations. A simulator always reports a zero IDFA.

## Logs

The app delegate turns on every BidMachine log before the adapter initialises the SDK: the public
SDK, bid, event, sanitizer and adapter switches, plus the internal feature flags for analytics,
adaptive rendering, MRAID, state groups, GAM and the database. The SDK writes them through OSLog
under the app's bundle identifier as subsystem, category `BidMachineIntegration`, so they show in
the Xcode console. From the command line, stream them at debug level:

```
xcrun simctl spawn booted log stream --level debug \
  --predicate 'subsystem == "io.bidmachine.AdLoaderExample"'
```

Launching with `OS_ACTIVITY_MODE=disable` in the environment makes the SDK print to stdout
instead, which is what `simctl launch --console` captures.

The lines that matter, in order:

```
BidMachineAdapter: Collecting banner signals with no size
[..B..] Bid - <id> [mraid][banner(width: 0, height: 0, isAdaptive: true)] complete
```

The first is the adapter on this branch; the second is the SDK's bid token placement, width 0.
With the 3.7.3.0 fix the adapter logs the screen width it substituted and the token carries it.
