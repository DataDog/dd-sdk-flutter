# Datadog Flutter Plugin: WebView Session Replay example

This example shows Session Replay recording a WebView whose page runs the
Datadog Browser SDK, in a Flutter-only app (no native Session Replay). The web
content joins the same replay as the Flutter screens.

It uses `datadog_session_replay` together with `datadog_webview_tracking` and
`webview_flutter`. iOS only for now.

## Setup

Generate the local `.env` file from the repository root, then run this example:

```bash
melos generate_env
flutter run
```

Runtime credentials come from `.env`, which is ignored by Git. Do not commit
real client tokens or application IDs.

> **Note:** iOS WebView tracking only asks the Browser SDK for replay records
> when it finds Session Replay registered under the native `session-replay`
> name. Flutter Session Replay registers a stand-in there when it runs
> standalone, so if the page reports `capabilities: []`, check that Session
> Replay was enabled before the WebView was tracked.

## What to check

1. Open the WebView screen. The bar above the page shows what the native bridge
   advertises: `capabilities` must be `["records"]`, and `privacy` is the web
   privacy level matching the Flutter privacy levels in `main.dart`. The same
   report is printed to the console with a `[WEBVIEW-SR]` prefix. In bridge
   mode the Browser SDK doesn't own the session, so the `session` and
   `replay link` it shows are placeholders: find the replay from the app's RUM
   session instead.
2. Interact with the page, go back, and open the session's replay in Datadog.
   The web content plays inside the WebView's area, and stops showing once the
   WebView screen is closed.

## How it works

* Session Replay is enabled before any WebView is tracked. Whether the Browser
  SDK sends replay records is decided when `trackDatadogEvents` runs.
* `trackDatadogEvents` is called before the page loads, so the bridge is in
  place when the Browser SDK starts.
* Only the global privacy levels apply to web content. `SessionReplayPrivacy`
  widgets don't affect what the Browser SDK records.

For unattended runs, `--dart-define=AUTO_OPEN_WEBVIEW=true` opens the WebView
screen after 5 seconds, and `--dart-define=AUTO_POP_WEBVIEW=true` also closes
it 20 seconds later.
