# Datadog Flutter Plugin Setup

To setup Datadog log collection or Real User Monitoring (RUM), you should use the [Datadog Flutter Plugin][1]. Setup will differ slightly depending on whether you want to use logging, RUM, or both, but most of the setup steps will be the same.

## Ensure proper versions

First, ensure that you have your environment set up properly for each platform. Currently, Datadog officially supports iOS and Android, with alpha support for Flutter Web.

### iOS

Your iOS Podfile (located in `ios/Podfile`) must have `use_frameworks!` set (which is true by default in Flutter) and must set its target iOS version >= 11.0. This constraint is usually commented out on the top line of the Podfile, and should read:

```ruby
platform :ios, '11.0'
```

11.0 can be replaced with whatever minimum version of iOS you want to support, but must be 11.0 or higher.

### Android

On Android, your `minSdkVersion` must be >= 19, and if you are using Kotlin, it should be version >= 1.5.31. These constraints are usually head in your `app/build.gradle` file.

### Web

`⚠️ Datadog support for Flutter Web is still in early development`

On Web, add the following to your `index.html` under your `head` tag:

```html
<script type="text/javascript" src="https://www.datadoghq-browser-agent.com/datadog-logs-v4.js"></script>
<script type="text/javascript" src="https://www.datadoghq-browser-agent.com/datadog-rum-slim-v4.js"></script>
```

This loads the CDN-delivered Datadog Logging and RUM Browser SDKs. Note that the synchronous CDN-delivered version of the Browser SDK is the only version supported by the Flutter plugin.

## Setup

### Modify your pubspec.yaml

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  datadog_flutter_plugin: ^1.0.0-rc.1
```

### Create configuration object

Create a configuration object for each Datadog feature (such as Logging or RUM) with the following snippet. If you do not pass a configuration for a given feature, that feature is disabled.

If you are using RUM, follow the instructions in for [RUM Collection](rum/rum_collection.md) to setup a **Client Token** and **Application Id**. If you are only using Logging, you can initialize the library with only a [Datadog client token][3]. For security reasons, you must use a client token: you cannot use Datadog API keys to configure the Datadog Flutter Plugin. For more information about setting up a client token, see the client token documentation:

```dart
// Determine the user's consent to be tracked
final trackingConsent = ...
final configuration = DdSdkConfiguration(
  clientToken: '<CLIENT_TOKEN>',
  env: '<ENV_NAME>',
  site: DatadogSite.us1,
  trackingConsent: trackingConsent,
  nativeCrashReportEnabled: true,
  loggingConfiguration: LoggingConfiguration(
    sendNetworkInfo: true,
    printLogsToConsole: true,
  ),
  rumConfiguration: RumConfiguration(
    applicationId: '<RUM_APPLICATION_ID>',
  )
);
```

For more information on available configuration options, see the [DdSdkConfiguration object][4] documentation.

### Initialize the library

You can initialize RUM using one of two methods in your `main.dart` file.

1. Use `DatadogSdk.runApp`, which automatically sets up error reporting. 

   ```dart
   await DatadogSdk.runApp(configuration, () async {
     runApp(const MyApp());
   })
   ```

2. Alternatively, you can manually set up error tracking and resource tracking. Because `DatadogSdk.runApp` calls `WidgetsFlutterBinding.ensureInitialized`, if you are not using `DatadogSdk.runApp`, you need to call this method prior to calling `DatadogSdk.instance.initialize`.

   ```dart
   runZonedGuarded(() async {
     WidgetsFlutterBinding.ensureInitialized();
     final originalOnError = FlutterError.onError;
     FlutterError.onError = (details) {
       FlutterError.presentError(details);
       DatadogSdk.instance.rum?.handleFlutterError(details);
       originalOnError?.call(details);
     };

     await DatadogSdk.instance.initialize(configuration);

     runApp(const MyApp());
   }, (e, s) {
     DatadogSdk.instance.rum?.addErrorInfo(
       e.toString(),
       RumErrorSource.source,
       stackTrace: s,
     );
   });
   ```

To be compliant with the GDPR regulation, the SDK requires the `trackingConsent` value at initialization.
The `trackingConsent` can be one of the following values:

- `TrackingConsent.pending` - the SDK starts collecting and batching the data but does not send it to Datadog. The SDK waits for the new tracking consent value to decide what to do with the batched data.
- `TrackingConsent.granted` - the SDK starts collecting the data and sends it to Datadog.
- `TrackingConsent.notGranted` - the SDK does not collect any data: logs, traces, and RUM events are not sent to Datadog.

To change the tracking consent value after the SDK is initialized, use the `DatadogSdk.setTrackingConsent` API call.
The SDK changes its behavior according to the new value. For example, if the current tracking consent is `TrackingConsent.pending`:

- if changed to `TrackingConsent.granted`, the SDK will send all current and future data to Datadog;
- if changed to `TrackingConsent.notGranted`, the SDK will wipe all current data and will not collect any future data.

## Further Reading

{{< partial name="whats-next/whats-next.html" >}}

[1]: https://pub.dev/packages/datadog_flutter_plugin
[2]: https://app.datadoghq.com/rum/application/create
[3]: https://docs.datadoghq.com/account_management/api-app-keys/#client-tokens
[4]: https://pub.dev/documentation/datadog_flutter_plugin/latest/datadog_flutter_plugin/DdSdkConfiguration-class.html