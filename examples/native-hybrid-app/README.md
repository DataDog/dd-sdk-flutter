# "Add-To-App" or Hybrid Native + Flutter Applciation Example

This example covers how to use the Datadog Flutter SDK in conjunction with an already existing native application. This assumes you already have a native iOS or Android Application that is sending data to Datadog, and you have added Flutter to it following Flutter's [Add-to-app documentation](https://docs.flutter.dev/development/add-to-app).

## Native App is Primary and Datadog is Already Initialized -  `attachToExisting`

If you are using an application that is already using the native Datadog iOS or Datadog Android SDKs, the Flutter SDK can attach to these using the same parameters. In your `main` function, after calling `WidgetsFlutterBinding.ensureInitialized`, call `DatadogSdk.instance.attachToExisting`. You can optionally add a `LoggingConfiguraiton` to this call, which automatically creates a global logger and attaches it to `DatadogSdk.logs`.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = DdSdkExistingConfiguration(
    loggingConfiguration: LoggingConfiguration()
  );

  await DatadogSdk.instance.attachToExisting(config);

  runApp(MyApp());
}
```

Additional options for `DdSdkExistingConfiguration` are documented in the [API reference](https://pub.dev/documentation/datadog_flutter_plugin/latest/datadog_flutter_plugin/datadog_flutter_plugin-library.html). Note that options in this class need to be re-specified even if they are already passed during Native SDK initialization.

### Avoiding "FlutterViewController" and "FlutterActivity" views

Depending on your settings, the automatic view tracking in the native iOS and Android SDKs will automatically track the presentation of the `FlutterViewController` and `FlutterActivity`/`FlutterFragment` when they appear, and then immediately add show a view load for your tracked Flutter view.

To avoid seeing the extra `FlutterViewController` and `FlutterActivity` views in your sessions, add a `UIKitRUMViewsPredicate` and `ComponentPredicate` to your iOS and Android code, respectively.  Very simple examples of these predicates can be found in the example code in [AppDelegate.swift](ios/iOS%20Flutter%20Hybrid%20Example/AppDelegate.swift) and [HybridApplication.kt](android/app/src/main/java/com/datadoghq/hybrid_flutter_example/HybridApplication.kt)

### Restart iOS Views

If you are using automatic view tracking on iOS and filtering `FlutterViewController` views with the predicate above, there is a known issue that transitioning back from the `FlutterViewController` does not restart the original view, so you have to perform this step manually.

This app uses a `MethodChannel` on iOS specifically for dismissing the `FlutterViewController`. The `MethodChannel` allows a single use block to be triggered when the 'dismiss' method is called, which allows the presenting `ViewController` to also handle dismissal and restart the RUM view. You can see this helper class interaction in [AppDelegate.swift](ios/iOS%20Flutter%20Hybrid%20Example/AppDelegate.swift) and in [my_app.dart](flutter_modules/lib/my_app.dart).

Note that restarting the view in this way is not necessary if you are not using the `UIKitRumViewsPredicate` to prevent "FlutterViewController" from appearing in your sessions.

### Caveats

* The `source` of the data coming from these Hybrid apps is always the Native platform, no matter whether the event was sent from the Native SDK or the Flutter SDK.

## Flutter App is Primary - use Datadog as Normal

If you are primarily using Flutter and only occasionally need to access the Native Datadog SDK from a few views, you can assume Datadog has already been initialized and use some of its functionality without issue

/// TODO - Example

### Caveats

* The Datadog Flutter SDK uses its own View, User Action and Resource tracking, so these are disabled when Flutter performs the initialization. You must manually track views and user actions in this scenario.

// TODO - iOS and Android Example
