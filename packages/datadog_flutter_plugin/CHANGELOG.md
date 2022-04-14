# Changelog

## Unreleased

* Update iOS SDK to 1.10
  * For a full list of changes see the [iOS Changelog](https://github.com/DataDog/dd-sdk-ios/blob/develop/CHANGELOG.md#1100--04-12-2022)
* Send `firstPartyHosts` to Native SDKs during initialization. Make
  `firstPartyHosts` property on read only `DatadogSdk` read only. 

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
