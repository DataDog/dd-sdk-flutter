# Changelog

## Unreleased



## 1.0.2

* Add methods for enabling the DatadogTrackingHttpClient in add-to-app scenarios.
* Send trace sample rate (`dd.rule_psr`) for APM's traffic ingestion control page.
* Added DatadogClient for use with the `http` pub package.
* Fix an issue where convenience methods on DatadogTrackingHttpClient weren't being tracked properly
* Support for OTel `b3` and W3C `tracecontext` header injection

## 1.0.1

* Stable release of 1.0.x

## 1.0.1-rc.1

* 💥 BREAKING - Set the 1.0.x line to be Dart 2.15 (Flutter 2.8) and below. If you are using Dart 2.17 (Flutter 3) please use the 1.1.x line.
* Updated to use `datadog_flutter_plugin` 1.0.0-rc.1

## 1.0.0-beta.2

* Decrease the SDK constraint from Dart 2.16 (Flutter 2.10) to Dart 2.15 (Flutter 2.8)

## 1.1.0

* Minor documentation update to clarify 1.1.x / 1.0.x changes

## 1.1.0-rc.1

* Updated to use `datadog_flutter_plugin` 1.0.0-rc.1
* Added internal error reporting (telemetry)

## 1.0.1

* Stable release of 1.0.x

## 1.0.1-rc.1

* 💥 BREAKING - Set the 1.0.x line to be Dart 2.15 (Flutter 2.8) and below. If you are using Dart 2.17 (Flutter 3), use the 1.1.x line.
* Updated to use `datadog_flutter_plugin` 1.0.0-rc.1
* Added internal error reporting (telemetry)

## 1.0.1-beta.1

* Add methods for Dart 2.17, set minimum supported version to Dart 2.17

## 1.0.0-beta.2

* Decrease the SDK constraint from Dart 2.16 (Flutter 2.10) to Dart 2.15 (Flutter 2.8)

## 1.0.0-beta.1

* Removed using platform traces / spans in DatadogTrackingHttpClient

## 1.0.0-alpha.1

* Initial split of DatadogTrackingHttpClient into its own package
