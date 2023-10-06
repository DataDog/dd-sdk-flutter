# "Add-To-App" or Hybrid Native + Flutter Applciation Example

This example covers how to use the Datadog Flutter SDK in conjunction with an already existing native application. This assumes you already have a native iOS or Android application that is sending data to Datadog, and you have added Flutter to it following Flutter's [Add-to-app documentation](https://docs.flutter.dev/development/add-to-app).

## Native app is primary and Datadog is already initialized -  `attachToExisting`

If you are using an application that is already using the native Datadog iOS or Datadog Android SDKs, the Flutter SDK can attach to these using the same parameters. In your `main` function, after calling `WidgetsFlutterBinding.ensureInitialized`, call `DatadogSdk.instance.attachToExisting`.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = DatadogAttachConfiguration(
    reportFlutterPerformance: true,
  );

  await DatadogSdk.instance.attachToExisting(config);

  runApp(MyApp());
}
```

Additional options for `DdSdkExistingConfiguration` are documented in the [API reference](https://pub.dev/documentation/datadog_flutter_plugin/latest/datadog_flutter_plugin/datadog_flutter_plugin-library.html). Note that options in this class need to be re-specified even if they are already passed during Native SDK initialization.

### Avoiding "FlutterViewController" and "FlutterActivity" views

Depending on your settings, the automatic view tracking in the native iOS and Android SDKs will automatically track the presentation of the `FlutterViewController` and `FlutterActivity`/`FlutterFragment` when they appear, and then immediately show a view load for your tracked Flutter view. To avoid seeing the extra `FlutterViewController` and `FlutterActivity` views in your sessions, add a view predicate to filter them.

On iOS, create a `UIKitRUMViewsPredicate` to check if the view controller is an instance of `FlutterViewController`. On iOS 13+, return `nil` from this function and the RUM iOS SDK stops tracking the `FlutterViewController` and lets the Flutter SDK take over, provided `isModalInPresentation` is set to true. If you are targeting iOS version lower than 13, or `isModalInPresentation` is not set to true, instead return a `RUMView` with the `isUntrackedModal` property set to `true`. This ensures that your previous view is properly restarted. An example of this predicate can be found in the example code in [AppDelegate.swift](ios/iOS%20Flutter%20Hybrid%20Example/AppDelegate.swift)

On Android, create a `ComponentPredicate` to check if the Activity is an instance of `FlutterActivity`. If so, return false from this function to avoid tracking the Activity and let Flutter SDK take over.  An example of this predicate can be found in the example code in [HybridApplication.kt](android/app/src/main/java/com/datadoghq/hybrid_flutter_example/HybridApplication.kt)

### Caveats

* The `source` of the data coming from these Hybrid apps is always the Native platform, no matter whether the event was sent from the Native SDK or the Flutter SDK.
* Currently, you can only embed your Flutter app using Cocoapods, documented as "Option A" in [Flutter's documentation](https://docs.flutter.dev/add-to-app/ios/project-setup#option-a---embed-with-cocoapods-and-the-flutter-sdk). Using `.xcframeworks` (Options B and C) will generate compiler errors, especially if you are already using Datadog in your native project. See our [Github Issue](https://github.com/DataDog/dd-sdk-flutter/issues/443) for more details.

## Flutter app is primary - use Datadog as normal

If you are primarily using Flutter and only occasionally need to access the Native Datadog SDK from a few views, you can assume Datadog has already been initialized and use some of its functionality without issue

/// TODO - Example

### Caveats

* The Datadog Flutter SDK uses its own View, User Action and Resource tracking, so these are disabled when Flutter performs the initialization. You must manually track views and user actions in this scenario.

// TODO - iOS and Android Example
