# Changelog

## Unreleased

* Cancel spans on DatadogTrackingHttpClient when RUM is enabled (prevent spans
  from leaking native resources)
* Remove native view tracking (Activities and Fragments) from Android by default

## 1.0.0-alpha.1

* Support for Logging, Tracing (including Datadog Distributed Tracing) and RUM
  * iOS Support with Datadog SDK for iOS 1.9.0
  * Android Support with Datadog SDK for Android 1.12.0-alpha2
* Automatically track network requests with `DatadogTrackingHttpClient`
* Error reporting for iOS, Android, and Android NDK crashes.
