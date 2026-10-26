# Changelog

## 2.0.0

### Breaking Changes

- Require Dart 3.10 and Flutter 3.38 or later.
- Require `datadog_flags: ^2.0.0`.
- When using `datadog_flutter_plugin` 4.x, supply a `service` name in `DatadogConfiguration` (#1105).

### Features

- Export `DatadogOpenFeatureProvider` and add `DatadogRumHook` to associate successful OpenFeature evaluations with the active RUM view (#1134).
- Deprecate `DatadogFlagsPlugin` and `DatadogFlagsPluginConfiguration`. Use the OpenFeature provider and RUM hook for new integrations (#1134).
- Support obfuscated assignment keys without changes to application flag keys (#1188).

### Fixes

- Report `CACHED` when an evaluation uses an assignment restored from local storage (#1209).

## 1.1.0

* Forward `DatadogFlagsConfiguration.initializationTimeout` to the core SDK. The first context initialization has a five-second timeout by default. Set it to `null`, zero, or a negative duration to disable it.
* Export and forward `FlagsInitializationTimeoutException` when initialization exceeds the timeout. Catch this exception to continue application startup. The assignment operation continues and can make assignments available later.
* Require `datadog_flags: ^1.1.0` so the core SDK supports initialization timeouts.
* Support `datadog_flutter_plugin` versions from 3.4.0 through 4.x.

## 1.0.0

* Add Flutter integration for Datadog feature flags, including Datadog SDK configuration derivation and RUM feature flag evaluations.
