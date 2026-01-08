# Changelog

## 2.0.0

* Support RUM context in trace headers.
* Support consistent sampling based on session id.
* [Web] Fix conversion of List to JSArray for Flutter Web.
* Support deterministic sampling decisions on distributed traces.

## 1.2.0

* Support grpc 4.x. See [#704](https://github.com/DataDog/dd-sdk-flutter/issues/704).
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
