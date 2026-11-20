# Changelog

## 1.2.0

### Features

- `DatadogFlagsConfiguration` now supports a `flagSelection` option (via a new `FlagSelection` type) that limits fetched flags to those matching selected tags or key patterns, reducing payload size, with errors and server rejections logged and diagnostics available in any build mode by setting `DatadogProvider.verbosity` to a `FlagsLoggerLevel` (`debug`, `warning`, `error`).
- Added a public `ExposureHook` for OpenFeature that lets applications record flag exposures to their own data store, receiving each completed evaluation's exposure status, cache-hit status, send status, flag key, variant, allocation key, targeting key, context, and any `HOOK`-destined split features.
- Added opt-in strict evaluation context switching, enabled via the `dd_strict_evaluation_context_switching` context attribute, to immediately discard stale assignments on a targeting-key change instead of retaining them.

### Fixes

- Fixed an issue where a targeting-key change could serve cached flag assignments belonging to a different subject; by default, the SDK now returns default values during the change and retains assignments only when the targeting key stays the same.
- Fixed OpenFeature exposure tracking so exposures are only recorded and sent once the entire evaluation, including all hooks, completes successfully, rather than immediately at resolve time; calling a `DatadogOpenFeatureProvider.resolve...Value` method directly, outside an OpenFeature client, no longer records an exposure.
- Fixed RUM hooks so they reliably tag the final successful evaluation result instead of sometimes missing or misreporting evaluations.
- Fixed flag refresh so a failed or late response no longer blocks recovery, and telemetry is now preserved through failures and late responses.
- Fixed flag evaluations restored from the local cache to report a `CACHED` reason instead of the reason from the network response that originally populated the cache.

## 1.1.0

* Forward `DatadogFlagsConfiguration.initializationTimeout` to the core SDK. The first context initialization has a five-second timeout by default. Set it to `null`, zero, or a negative duration to disable it.
* Export and forward `FlagsInitializationTimeoutException` when initialization exceeds the timeout. Catch this exception to continue application startup. The assignment operation continues and can make assignments available later.
* Require `datadog_flags: ^1.1.0` so the core SDK supports initialization timeouts.
* Support `datadog_flutter_plugin` versions from 3.4.0 through 4.x.

## 1.0.0

* Add Flutter integration for Datadog feature flags, including Datadog SDK configuration derivation and RUM feature flag evaluations.
