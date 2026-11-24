# Changelog

## 1.2.0

### Breaking Changes

- The minimum supported versions are now Dart 3.10 and Flutter 3.38. Upgrade Dart and Flutter before you update to this version.

### Features

- Adds `FlagSelection` (with `tags` and `keyPatterns`) and `DatadogFlagsConfiguration.flagSelection`, so apps can fetch only the flags that match selected tags or key patterns instead of the full configuration.
- Adds `ExposureHook` for `DatadogOpenFeatureProvider` to observe every completed evaluation: flag key, variant, allocation key, targeting key, context, and `HOOK` features. The hook uses the same exposure and deduplication decisions as the SDK. If the callback fails, evaluation is unaffected.
- Flag assignments can now carry `features` for the selected split, with `HOOK`-destination features exposed in flag metadata under keys prefixed `__dd_feature.`.
- Adds `FlagsLoggerLevel` and `DatadogProvider.verbosity` to enable opt-in SDK diagnostic logging (including flag-selection warnings) at `debug`, `warning`, or `error` levels, visible even in release builds.

### Fixes

- Fixes OpenFeature evaluation context handling so that changing the targeting key no longer serves another subject's assignments. Default values are returned while new assignments load. To enable strict mode, set the `dd_strict_evaluation_context_switching` context attribute to `true`.
- Exposures recorded through the OpenFeature provider are sent only after the whole evaluation, including later hooks, succeeds. Previously, exposures were sent at resolve time, even when a later hook failed.
- Fixes issues where a context refresh could prevent recovery of valid assignments and where RUM hooks could miss or misreport flag evaluations.
- Successful flag evaluation details now report a `CACHED` reason when the active assignments were restored from the configured store, instead of incorrectly retaining the previous network response's reason.

## 1.1.0

* Forward `DatadogFlagsConfiguration.initializationTimeout` to the core SDK. The first context initialization has a five-second timeout by default. Set it to `null`, zero, or a negative duration to disable it.
* Export and forward `FlagsInitializationTimeoutException` when initialization exceeds the timeout. Catch this exception to continue application startup. The assignment operation continues and can make assignments available later.
* Require `datadog_flags: ^1.1.0` so the core SDK supports initialization timeouts.
* Support `datadog_flutter_plugin` versions from 3.4.0 through 4.x.

## 1.0.0

* Add Flutter integration for Datadog feature flags, including Datadog SDK configuration derivation and RUM feature flag evaluations.
