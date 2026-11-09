# Changelog

## 1.2.0

### Fixes

- Flag evaluation details now report `CACHED` when the assignment is restored from the configured store, instead of reusing the earlier network response reason.

## 1.1.0

* Forward `DatadogFlagsConfiguration.initializationTimeout` to the core SDK. The first context initialization has a five-second timeout by default. Set it to `null`, zero, or a negative duration to disable it.
* Export and forward `FlagsInitializationTimeoutException` when initialization exceeds the timeout. Catch this exception to continue application startup. The assignment operation continues and can make assignments available later.
* Require `datadog_flags: ^1.1.0` so the core SDK supports initialization timeouts.
* Support `datadog_flutter_plugin` versions from 3.4.0 through 4.x.

## 1.0.0

* Add Flutter integration for Datadog feature flags, including Datadog SDK configuration derivation and RUM feature flag evaluations.
