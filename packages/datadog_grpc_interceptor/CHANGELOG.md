# Changelog

## Unreleased

* Add support for `TraceContextInjection` configuration.

## 1.1.0

* Support 128-bit trace ids in distributed tracing.

## 1.0.1

* Constrain compatible `datadog_flutter_plugin` to <2.5.0

# 1.0.0

* First official release.
* Update to v2.0 of Datadog SDKs.

## 1.0.0-beta.2

* Send trace sample rate (`_dd.rule_psr`) for APM's traffic ingestion control page.
* Support for OTel `b3` and W3C `tracecontext` header injection

## 1.0.0-beta.1

* Initial release of the gRPC client interceptor.
