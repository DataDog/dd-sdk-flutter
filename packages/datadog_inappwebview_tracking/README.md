## Overview

This package is an extension to the [`datadog_flutter_plugin`][1]. It allows Real User Monitoring to monitor web views created by the [`flutter_inappwebview`][2] package and eliminate blind spots in your hybrid Flutter applications.

> [!WARNING]
> This plugin does not currently support Flutter Web

## Instrumenting your web views

The RUM Flutter SDK provides APIs for you to control web view tracking when using the [`flutter_inappwebview`][2] package.

Add both the `datadog_inappwebview_tracking` package and the `flutter_inappwebview` package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_inappwebview: ^6.1.5
  datadog_flutter_plugin: ^3.0.0
  datadog_inappwebview_tracking: ^1.0.0
```

### InAppWebView

To instrument an `InAppWebView`, add the `DatadogInAppWebViewUserScript` to your `initialUserScripts`, and call the `trackDatadogEvents` extension method during the `onWebViewCreated` callback:

```dart
InAppWebView(
  // Other settings...
  initialUserScripts: UnmodifiableListView([
    DatadogInAppWebViewUserScript(
      datadog: DatadogSdk.instance,
      allowedHosts: {'shopist.io'},
    ),
  ]),
  onWebViewCreated: (controller) async {
    controller.trackDatadogEvents(DatadogSdk.instance);
  },
)
```

### InAppBrowser

> [!WARNING]
> `InAppBrowser` is not tracked on Android 33+ because of [this bug](https://github.com/pichillilorenzo/flutter_inappwebview/issues/1973). This will be fixed by plugin versions that depends on `flutter_inappwebview 6.2.0`.

To instrument an `InAppBrowser`, add an override for `onBrowserCreated` and call the `trackDatadogEvents` extension method on `webViewController`, then add a `DatadogInAppWebViewUserScript` to the `initialUserScripts` when creating your custom `InAppBrowser`:

```dart
class MyInAppBrowser extends InAppBrowser {
  MyInAppBrowser({super.windowId, super.initialUserScripts});

  @override
  void onBrowserCreated() {
    webViewController?.trackDatadogEvents(DatadogSdk.instance);
    super.onBrowserCreated();
  }
}

// Browser creation
_browser = MyInAppBrowser(
  initialUserScripts: UnmodifiableListView(
    [
      DatadogInAppWebViewUserScript(
        datadog: DatadogSdk.instance,
        allowedHosts: {'shopist.io'},
      ),
    ],
  ),
);
```


[1]: https://pub.dev/packages/datadog_flutter_plugin
[2]: https://pub.dev/packages/flutter_inappwebview
