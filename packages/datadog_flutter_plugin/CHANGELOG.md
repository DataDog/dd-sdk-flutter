# Changelog

## 2.1.0

* `DatadogLogger` will no longer leak its reference to its native Logger.
* Fix debug output from native `DatadogSdk` on iOS.
* Fix `LogLevel` being private. See [#518]
* Make `DatadogRumPlugin` a singleton on Android to avoid losing its connection to the `RUMMonitor` during backgrounding.
* Update iOS SDK to 2.5.0. For a full list of changes, see the [iOS Changelog](https://github.com/DataDog/dd-sdk-ios/blob/develop/CHANGELOG.md#250--08-11-2023)
* Update Android SDK to 2.3.0. For a full list of changes, see the [Android Changelog](https://github.com/DataDog/dd-sdk-android/blob/develop/CHANGELOG.md#230--2023-11-21)
  * Make NDK stack traces more standard.
  * Make sure we use try-locks in our NDK signal catcher.

## 2.0.0

Release 2.0 introduces breaking changes. Follow the [Migration Guide](MIGRATING.md) to upgrade from 1.x

* Update to v2.0 of Datadog SDKs.
* Update UUID to ^4.0. See [#472]
* Change default tracing headers for first party hosts to use both Datadog headers and W3C tracecontext headers.
* Fix automatic resource tracking for Flutter Web

## 1.6.0

* Fix an issue where failing to load Datadog modules on Web threw an error (and potentially broke application loading).
* Add the ability to specify a sampling rate for loggers.
* Add a "NoOp" platform, usable when performing headless Flutter widget tests.
* Update iOS SDK to 1.23.0
  * RUM payloads are now optimised by including less view updates
  * Prevent attributes from propagating from Errors and LongTasks to Views
* Added support for Gradle 8 from @wrbl606. See [#462]

## 1.5.1

* Update Android SDK to 1.19.2
  * Ignore adding custom timings and feature flags for the stopped view.

## 1.5.0

* Use `PlatformDispatcher.onError` over `runZonedGuarded` for automatic error tracking and to avoid a Zone mismatch exception in Flutter 3.10. See [#416]
* Increase minimum Flutter version to 3.3, Dart 2.18, fully support Futter 3.10 / Dart 3
* Another attempt to fix the crash on exit on iOS. See [#414]
* Fix an issue where calls into Datadog would not provide accurate stack traces.

## 1.4.0

* Add the ability to stop a RUM session. A new session is started on the next user interaction or on the next view start. See [#147]
* Increase minimum Flutter version to 3.0, Dart 2.17. See [#386]
* Update Android SDK to 1.19.0. For a full list of changes see [https://github.com/DataDog/dd-sdk-android/releases/tag/1.19.0]
* Update iOS SDK to 1.19.0. For a full list of changes see [https://github.com/DataDog/dd-sdk-ios/releases/tag/1.19.0]

## 1.3.3

* Fix a crash on exit on iOS. See [#390]

## 1.3.2

* Add Web View tracking through the `webview_flutter` package.
* Bind `consolePrint` callback earlier in iOS to make sure initialization errors can be seen in the console. See [#328]
* Fix `version` not properly populating on Flutter Web. See [#334]
* Improve `RumUserActionDetector` to detect more widgets, including `BottomNavigationBar`, `Tab`, `Switch`, and `Radio`
* Remove an extra call to `FlutterError.presentError` made in `runApp`.  See [#358]
* Set `sessionReplaySampleRate` to 0 during initialization for Browser as Session Replay is not supported.
* Support `errorType` on `DdRum.addError` and `DdRum.addErrorInfo`. See [#372]

## 1.2.3

* Fix b3 and tracecontext using incorrect Trace and Span ids during request tracking.

## 1.2.2

* Potentially fix a crash on exit on iOS. See [#341]

## 1.2.1

* Remove reference to a gradle file that was not included in `pub deploy`

## 1.2.0

* 🔥 BREAKING - Log functions (`debug`, `info`, `warn`) now use `attributes` as a named argument instead of a positional argument.
* Allow errors to be sent on all log functions. See [#264][]
* Disable tracing by default in iOS. Silences a benign warning from the SDK. See [#280][]
* Add ability to modify logs before send with `logEventMapper`
* Allow setting sdkVerbosity prior to calling `DatadogSdk.runApp`
* Update Android SDK to 1.16.0
  * Logs: Make a local copy of tags before creating `LogEvent`.
  * RUM: Synchronize access to `DatadogRumMonitor#rootScope` when processing fatal error.
  * Logs: Add `device.architecture` to logs.
  * Logs: Add a logger method to log error information from strings.
  * RUM: Add frustration signal 'Error Tap'.
  * RUM: Report frustration count on views.
  * RUM: Create internal API for sending technical performance metrics.
* Update iOS SDK to 1.14.0
  * Add a method for sending error attributes on logs as strings
  * Add a method to add user info properties.

## 1.1.0

* Add methods for attaching to existing instances of the DatadogSdk for "add-to-app" scenarios.
* Add `addUserExtraInfo` method for providing extra user attributes without overwriting other user info. See [#254][]
* Add `RumConfiguration.vitalUpdateFrequency` to allow control over how often the Native SDKs query for vitals (CPU and memory usage).
* Fix a crash caused by attempting to send logs while an app was terminating See [#271][]

## 1.0.1

* Update Android SDK to 1.14.1
  * Add CPU architecture to the collected device information.

## 1.0.0

* Deprecation - `DdSdkConfiguration.customEndpoint` has been deprecated in favor of `DdSdkConfiguration.customLogsEndpoint` and `RumConfiguration.customEndpoint`.
* Added `DdSdkConfiguration.version` configuration option for specifying a custom application version.
* Fix `null` values in attributes not being correctly encoded on iOS.
* Add `flavor` as a configuration parameter.
* Updated iOS SDK to 1.12.0
* Updated Android SDK to 1.14.0

## 1.0.0-rc.3

* 🔥 MAJOR - Fixed an issue on Android where Datadog would not properly reinitialize after backing out of an application (pressing the back button on the home screen) and returning to it.
* Fix Flutter 3 log spam regarding use of `?.` on WidgetBindings.instance. See [#203][]
* Sync long task threshold between Flutter and Native long task reporting.
* Fix an issue where events that contained lists from `dart:typed_data` (`Float32List`, `Uint8List`, etc) were not being encoded / sent on iOS.
* Update iOS SDK to 1.12.0-beta3

## 1.0.0-rc.2

* Fix an issue with using `WidgetBindings.instance` as a non-optional (Property is optional pre-Flutter 3.0)

## 1.0.0-rc.1

* Update Android SDK to 1.14.0-beta1
* Update iOS SDK to 1.12.0-beta2
  * Include the exact model information in RUM `device.model`. Also fixes [#133][]
* Remove deprecated tracing feature.
* Removed `RumHttpMethod.unknown` as it is translated GET on the native side anyway.
* Added Long Task reporting.

## 1.0.0-beta.3

* Update Android SDK to 1.13.0-rc1
  * Improve local LogCat messages from the SDK.
  * Disables vitals collection when app is in the background.
  * Fix updating Global RUM context when a view is stopped.
  * For a full list of changes see the [Android Changelog](https://github.com/DataDog/dd-sdk-android/blob/develop/CHANGELOG.md#1130--2022-05-24).
* Update iOS SDK to 1.11.0
  * For a full list of changes see the [iOS Changelog](https://github.com/DataDog/dd-sdk-ios/blob/develop/CHANGELOG.md#1110--13-06-2022)
* Made analysis rules stricter and switched several attribute map parameters from `Map<String, dynamic>` to `Map<String, Object?>` for better compatibility with `implicit-dynamic: false` See [#143][] and [#148][]
* Fix `serviceName` configuration parameter [#159][]

## 1.0.0-beta.2

* Update iOS SDK to 1.11-rc1
  * Allow manually tracked resources in RUM Sessions to detect first party hosts.
  * Better error message when encountering an invalid token (Fixes #117).
  * Fix RUM events to support configured `source` property.
  * For a full list of changes, see the [iOS Changelog](https://github.com/DataDog/dd-sdk-ios/blob/develop/CHANGELOG.md#1110-rc1--18-05-2022).
* Added `datadogReportingThreshold` to `LoggingConfiguration` to support only sending logs above a certain threshold to Datadog.
* Add support for setting a tracing sample rate for RUM.
* Expose `DdLogs` through the main package import. Added documentation to DdLogs.
* Added initial Flutter Web features and tests. Note: Flutter Web is not ready for production use.

## 1.0.0-beta.1

* Update iOS SDK to 1.11-beta2
  * Stop reporting pre-warmed application launch time.
  * Reduce the number of intermediate view events sent in RUM payloads.
  * For a full list of changes, see the [iOS Changelog](https://github.com/DataDog/dd-sdk-ios/blob/develop/CHANGELOG.md#1110-beta1--04-26-2022).
* Send `firstPartyHosts` to Native SDKs during initialization. Make
  `firstPartyHosts` property on read only `DatadogSdk` read only. 
* 💥 Breaking! - Deprecated non-RUM resource tracing.
* Properly report `source` as Flutter on iOS.

## 1.0.0-alpha.2

* Cancel spans on DatadogTrackingHttpClient when RUM is enabled (prevent spans
  from leaking native resources)
* Remove native view tracking (Activities and Fragments) from Android by default
* Add support for creating multiple named loggers: `DatadogSdk.createLogger` and
  `LoggingConfiguration.loggerName`
* Add support for configuring whether loggers send data to Datadog:
  `LoggingConfiguration.sendLogsToDatadog`
* 💥 Breaking! - Removed `DdSdkConfiguration.trackHttpClient`. This has been
  replaced with a standalone `datadog_tracking_http_client` package.
* 💥 Breaking! - `DdSdkConfiguration.site` is now a required parameter and no
  longer defaults to `DatadogSite.us1`

## 1.0.0-alpha.1

* Support for Logging, Tracing (including Datadog Distributed Tracing) and RUM
  * iOS Support with Datadog SDK for iOS 1.9.0
  * Android Support with Datadog SDK for Android 1.12.0-alpha2
* Automatically track network requests with `DatadogTrackingHttpClient`
* Error reporting for iOS, Android, and Android NDK crashes.

[#133]: https://github.com/DataDog/dd-sdk-flutter/issues/133
[#143]: https://github.com/DataDog/dd-sdk-flutter/issues/143
[#147]: https://github.com/DataDog/dd-sdk-flutter/issues/147
[#148]: https://github.com/DataDog/dd-sdk-flutter/issues/148
[#159]: https://github.com/DataDog/dd-sdk-flutter/issues/159
[#175]: https://github.com/DataDog/dd-sdk-flutter/issues/175
[#203]: https://github.com/DataDog/dd-sdk-flutter/issues/203
[#254]: https://github.com/DataDog/dd-sdk-flutter/issues/254
[#264]: https://github.com/DataDog/dd-sdk-flutter/issues/264
[#271]: https://github.com/DataDog/dd-sdk-flutter/issues/271
[#280]: https://github.com/DataDog/dd-sdk-flutter/issues/280
[#297]: https://github.com/DataDog/dd-sdk-flutter/issues/297
[#305]: https://github.com/DataDog/dd-sdk-flutter/issues/305
[#328]: https://github.com/DataDog/dd-sdk-flutter/issues/328
[#334]: https://github.com/DataDog/dd-sdk-flutter/issues/334
[#358]: https://github.com/DataDog/dd-sdk-flutter/issues/358
[#372]: https://github.com/DataDog/dd-sdk-flutter/issues/372
[#390]: https://github.com/DataDog/dd-sdk-flutter/issues/390
[#414]: https://github.com/DataDog/dd-sdk-flutter/issues/414
[#416]: https://github.com/DataDog/dd-sdk-flutter/issues/416
[#462]: https://github.com/DataDog/dd-sdk-flutter/issues/462
[#472]: https://github.com/DataDog/dd-sdk-flutter/issues/472
[#518]: https://github.com/DataDog/dd-sdk-flutter/issues/518