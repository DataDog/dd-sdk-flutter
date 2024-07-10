# Changelog

## Unreleased

* Add the ability to ignore tracking on specific url patterns with `ignoreUrlPatterns` when using the attach configuration.
* Add support for `TraceContextInjection` configuration.

## 2.2.0

* Support 128-bit trace ids in distributed tracing.

## 2.1.2

* Constrain compatible `datadog_flutter_plugin` to <2.5.0

## 2.1.1

* Fix `_TypeError` when request URL is matched `ignoreUrlPatterns`. See [#590] (Thanks [@ronnnnn][])

## 2.1.0

* Add the ability to ignore tracking on specific url patterns with `ignoreUrlPatterns`.

## 2.0.0

* Update to v2.0 of Datadog SDKs

## 1.4.0

* Update version constraints to allow 1.x.x versions of the `http` package.

## 1.3.1

* Fix not exporting `DatadogTrackingHttpClientListener` from @ClaireDavis.

## 1.3.0

* Have `DatadogTrackingHttpClient` use `HttpOverrides.current` if they already exist. See [#424] 
* Added `attributeProvider` parameter to `DatadogClient` to allow users provide attributes for RUM Resources automatically created by `DatadogClient`.
* Added `DatadogTrackingHttpClientListener` to allow users to provide attributes for RUM Resources created by `DatadogTrackingHttpClient`.
* Fix rethrown execptions on `close` not having the correct stack trace.

## 1.2.1

* Fix an invalid assertion when processing stream errors. See [#355]

## 1.2.0

* Add methods for enabling the DatadogTrackingHttpClient in add-to-app scenarios.
* Send trace sample rate (`dd.rule_psr`) for APM's traffic ingestion control page.
* Added DatadogClient for use with the `http` pub package.
* Fix an issue where convenience methods on DatadogTrackingHttpClient weren't being tracked properly
* Support for OTel `b3` and W3C `tracecontext` header injection

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

[#355]: https://github.com/DataDog/dd-sdk-flutter/issues/355
[#424]: https://github.com/DataDog/dd-sdk-flutter/issues/424
[#590]: https://github.com/DataDog/dd-sdk-flutter/pull/590
[@ronnnnn]: https://github.com/ronnnnn
