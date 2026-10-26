# Changelog

## 2.0.0

### Breaking Changes

- This package now requires Dart 3.10 and Flutter 3.38 or later.

### Features

- `datadog_flags` now transparently supports obfuscated flag key assignments returned by the backend, without requiring any changes to application flag evaluation code.
- Dependency version constraints are now relaxed, making it easier to use `datadog_flags` alongside packages with newer dependency requirements.

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
