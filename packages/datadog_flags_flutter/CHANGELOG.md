# Changelog

## Unreleased

### Breaking changes

* Add `onFirstFlags` to `DatadogFlagsClient`. External implementations and test fakes must implement the new method, which returns an unregister function. Coordinate the core and Flutter integration release before publishing; this source change does not assign a release version.

### Features

* Retain the first accepted flag-installation event for early and late registrations. Every active registration is delivered once in a microtask; its unregister function suppresses delivery not yet started.

## 1.1.0

* Forward `DatadogFlagsConfiguration.initializationTimeout` to the core SDK. The first context initialization has a five-second timeout by default. Set it to `null`, zero, or a negative duration to disable it.
* Export and forward `FlagsInitializationTimeoutException` when initialization exceeds the timeout. Catch this exception to continue application startup. The assignment operation continues and can make assignments available later.
* Require `datadog_flags: ^1.1.0` so the core SDK supports initialization timeouts.
* Support `datadog_flutter_plugin` versions from 3.4.0 through 4.x.

## 1.0.0

* Add Flutter integration for Datadog feature flags, including Datadog SDK configuration derivation and RUM feature flag evaluations.
