// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

/// A page running the Datadog Browser SDK with RUM and Session Replay.
///
/// Inside a tracked WebView the Browser SDK runs in bridge mode: it sends its
/// events and replay records to the native SDK instead of uploading them, so
/// they join the app's RUM session and replay.
///
/// The page also reports what the bridge advertises, which is the quickest way
/// to check the setup: `capabilities` must be `["records"]` for the Browser SDK
/// to record a replay. The same report is printed to the console with a
/// `[WEBVIEW-SR]` prefix.
String browserPage({
  required String applicationId,
  required String clientToken,
  required String env,
}) =>
    '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <script src="https://www.datadoghq-browser-agent.com/us1/v6/datadog-rum.js"></script>
  <script>
    window.DD_RUM && window.DD_RUM.init({
      applicationId: '$applicationId',
      clientToken: '$clientToken',
      site: 'datadoghq.com',
      service: 'webview-session-replay-example-web',
      env: '$env',
      sessionSampleRate: 100,
      sessionReplaySampleRate: 100,
      trackUserInteractions: true,
      defaultPrivacyLevel: 'allow',
    });
  </script>
  <style>
    body { font-family: -apple-system, sans-serif; margin: 16px; background: #f4f1fb; }
    h1 { font-size: 20px; }
    button, input { font-size: 16px; padding: 10px; margin: 6px 0; width: 100%; box-sizing: border-box; }
    #box { width: 60px; height: 60px; background: #7e57c2; border-radius: 8px; transition: transform .6s; }
    pre { background: #222; color: #9f9; padding: 8px; font-size: 11px; white-space: pre-wrap; word-break: break-all; }
  </style>
</head>
<body>
  <h1>Web content (Browser SDK)</h1>
  <p>Interact here, then find this page in the app's Session Replay.</p>
  <input placeholder="Web text field">
  <button id="tap">Web taps: 0</button>
  <div id="box"></div>
  <pre id="diag">collecting…</pre>
  <script>
    var taps = 0, angle = 0;
    document.getElementById('tap').addEventListener('click', function () {
      taps++;
      this.textContent = 'Web taps: ' + taps;
      angle += 90;
      document.getElementById('box').style.transform = 'rotate(' + angle + 'deg)';
    });

    function report() {
      var bridge = window.DatadogEventBridge;
      var rum = window.DD_RUM;
      var ctx = rum && rum.getInternalContext ? rum.getInternalContext() : undefined;
      var lines = [
        'bridge: ' + (bridge ? 'present' : 'MISSING'),
        'capabilities: ' + (bridge && bridge.getCapabilities ? bridge.getCapabilities() : 'n/a'),
        'privacy: ' + (bridge && bridge.getPrivacyLevel ? bridge.getPrivacyLevel() : 'n/a'),
        'browser sdk: ' + (rum ? rum.version : 'NOT LOADED'),
        'session: ' + (ctx ? ctx.session_id : 'n/a'),
        'view: ' + (ctx && ctx.view ? ctx.view.id : 'n/a'),
        'replay link: ' + (rum && rum.getSessionReplayLink ? rum.getSessionReplayLink() : 'n/a'),
      ];
      var text = lines.join('\\n');
      document.getElementById('diag').textContent = text;
      if (window.Diagnostics) { window.Diagnostics.postMessage(text); }
    }
    setInterval(report, 3000);
    report();
  </script>
</body>
</html>
''';
