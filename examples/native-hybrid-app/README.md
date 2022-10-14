# "Add-To-App" or Hybrid Native + Flutter Applciation Example

This example covers how to use the Datadog Flutter SDK in conjunction with an already existing native application. This assumes you already have a native iOS or Android Application that is sending data to Datadog, and you have added Flutter to it following Flutter's [Add-to-app documentation](https://docs.flutter.dev/development/add-to-app).

## Native App is Primary and Datadog is Already Initialized -  `attachToExisting`

If you are using an applicaiton that is already using the native Datadog iOS or Datadog Android SDKs, the Flutter SDK can attach to these using the same parameters. In your `main` function, after calling `WidgetsFlutterBinding.ensureInitialized`, call `DatadogSdk.instance.attachToExisting`. You can optionally add a `LoggingConfiguraiton` to this call, which automatically creates a global logger and attaches it to `DatadogSdk.logs`.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatadogSdk.instance.attachToExisting();

  runApp(MyApp());
}
```

### Prewarmed and Cached Flutter Engines
The Flutter documentation on adding Flutter to an existing app for iOS uses a "prewarmed" Flutter engine by default (see [Create a FlutterEngine](https://docs.flutter.dev/development/add-to-app/ios/add-flutter-screen#create-a-flutterengine)) whereas the Android example does not (see [Launch a FlutterActivity](https://docs.flutter.dev/development/add-to-app/android/add-flutter-screen?tab=default-activity-launch-kotlin-tab#step-2-launch-flutteractivity)).

If you are using a "prewarmed" instance of the Flutter engine, note that iOS will immediately display the Flutter app's initial route, even though that route is off screen. This results in Datadog incorrectly showing the view starting as soon as the app starts.  Additionally, both prewarmed and cached Flutter engines can "hang on" to screens after the `FlutterViewController` or `FlutterActivity` are dismissed (you'll notice this as retained state when you leave and return to a Flutter screen). This also causes the Flutter Datadog Plugin to not report a new view, since Flutter did not actually perform the navigation.

For this reason, the example currently only uses non-prewarmed and non-cached versions of the Flutter engine.

### Caveats

* The `source` of the data coming from these Hybrid apps is always the Native platform, no matter whether the event was sent from the Native SDK or the Flutter SDK.

## Flutter App is Primary - use Datadog as Normal

If you are primarily using Flutter and only occasionally need to access the Native Datadog SDK from a few views, you can assume Datadog has already been initialized and use some of its functionality without issue.

/// TODO - Example

### Caveats

* The Datadog Flutter SDK uses its own View, User Action and Resource tracking, so these are disabled when Flutter performs the initialization. You must manually track views and user actions in this scenario.

// TODO - iOS and Android Example
