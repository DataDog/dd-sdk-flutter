## Overview

This package is an extension to the [`datadog_flutter_plugin`][1]. It allows 
Real User Monitoring allows to monitor web views and eliminate blind spots in your hybrid Flutter applications.

## Instrumentint your web views

The RUM Flutter SDK provides APIs for you to control web view tracking when using the [`webview_flutter`][2] package. 

Add both the `datadog_webview_tracking` package and the `webview_flutter` package to your `pubspec.yaml`:

```yaml
dependencies:
  webview_flutter: ^4.0.4
  datadog_flutter_plugin: ^1.3.0
  datadog_webview_tracking: ^1.0.0
```

To add Web View Tracking, call the `trackDatadogEvents` extension method on `WebViewController`, providing the list of allowed hosts.

For example:

```dart
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_webview_tracking/datadog_webview_tracking.dart';

webViewController = WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)
  ..trackDatadogEvents(
    DatadogSdk.instance,
    ['myapp.example'],
  )
  ..loadRequest(Uri.parse('myapp.example'));
```

Note that `JavaScriptMode.unrestricted` is required for tracking to work on Android.

[1]: https://pub.dev/packages/datadog_flutter_plugin
[2]: https://https://pub.dev/packages/webview_flutter