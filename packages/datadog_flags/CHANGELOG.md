# Changelog

## 1.2.0

### Breaking Changes

- The minimum supported versions are now Dart 3.10 and Flutter 3.38; upgrade your SDK before updating to this version.

### Features

- `DatadogFlagsConfiguration.flagSelection` lets you request only flags matching specific tags or key patterns, reducing the size of precompute requests and responses.
- Precomputed assignments can carry split `features`. `HOOK` features appear in flag metadata as `__dd_feature.<key>`.
- Adds an `ExposureHook` API for observing every OpenFeature evaluation, so you can record exposures in your own systems. The hook receives the exposure, cache-hit, and should-send status, along with the flag key, variant, allocation key, context, and features.
- Flag assignment keys can be hashed (obfuscated) in precompute requests and responses when the backend supports it. Evaluation calls don't need to change.
- Adds `FlagsLoggerLevel` and `DatadogProvider.verbosity` to configure opt-in diagnostic logging. Diagnostic logs also print in release builds and report errors, including server rejections of a flag selection.
- Relaxes dependency version constraints to allow newer major versions of underlying packages.

### Fixes

- Changing the evaluation context's targeting key returns default values instead of potentially serving another subject's assignments. Existing assignments are preserved by default. To reset assignments on any targeting-key change, set the `dd_strict_evaluation_context_switching` context attribute to `true`.
- Cached flag data is now scoped to site, environment, and client token.
- Exposures are recorded and sent only after an evaluation fully succeeds. Previously, exposures were recorded at resolve time, even when a later OpenFeature hook failed.
- Resolving a flag directly on `DatadogOpenFeatureProvider`, outside an OpenFeature client, no longer records an exposure.
- Fixes refresh, retry, and telemetry failures that could prevent recovery of valid assignments or cause flag evaluations to be missed or misreported.

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
