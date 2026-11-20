# Changelog

## 1.2.0

### Breaking Changes

- The minimum supported versions are now Dart 3.10 and Flutter 3.38; upgrade your toolchain before updating to this release.

### Features

- Added `FlagSelection` (via `DatadogFlagsConfiguration.flagSelection`) to request only flags matching specified tags or key patterns, reducing the size of fetched flag configurations and logging a clear message when a selection is dropped or ignored by the server.
- Added support for routed split `HOOK` features, which now appear in flag metadata as `__dd_feature.<key>`, along with a new `ExposureHook` API to record flag exposures into your own analytics using the same evaluation and deduplication logic as Datadog.
- Added `DatadogProvider.verbosity` (with the new `FlagsLoggerLevel` enum) to enable SDK diagnostic logging, including in release builds where the standard Dart developer log is suppressed.
- The SDK now transparently supports obfuscated flag keys returned by the server, with no changes required to application evaluation calls.
- Added opt-in strict evaluation context switching via the `dd_strict_evaluation_context_switching` context attribute, allowing applications to invalidate flag assignments immediately when the OpenFeature targeting key changes.

### Fixes

- Fixed an issue where changing the OpenFeature evaluation context could serve flag assignments for a different targeting key; by default, the SDK now returns default values until fresh assignments for the new targeting key are loaded, and retains existing assignments when the targeting key is unchanged.
- Fixed exposure events being recorded even when a later OpenFeature hook failed; exposures are now only recorded once the entire evaluation completes successfully.
- Fixed telemetry and caching issues around refresh failures and late responses, ensuring retries, cache recovery, and evaluation results are reported correctly.

## 1.1.1

* Fix missing Flutter Web flag evaluation counts by sending only supported Datadog metadata (#1196).

## 1.1.0

* Add `DatadogFlagsConfiguration.initializationTimeout` for the first context initialization. The default is five seconds. Set it to `null`, zero, or a negative duration to disable it.
* Complete `initialize()` with `FlagsInitializationTimeoutException` when initialization exceeds the timeout. Catch this exception to continue application startup. The assignment operation continues and can make assignments available later.
* Keep matching stored assignments available during initialization. Evaluations without assignments return the caller-provided default with `providerNotReady`.
* Preserve cache write ordering across SDK reconfiguration so pending writes cannot restore assignments after a reset.
* Include the assignment serial ID in exposure events when available. Send a new exposure when the serial ID changes.

## 1.0.1

* Fix Flutter Web flag evaluation events failing with HTTP 403 errors caused by CORS preflight requests.
* Preserve evaluation metadata when sending flag evaluation events from Flutter Web.

## 1.0.0

* Initial preview release of the native Dart Datadog Feature Flags and Experimentation SDK.
* Support precomputed assignment fetching, typed local evaluation, exposure tracking, flag evaluation tracking, and optional assignment storage.
