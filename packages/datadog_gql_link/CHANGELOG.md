# Changelog

## 2.1.0

* Add HTTP request and response header capture for RUM resources.
* Support payload capture for GraphQL Link.

## 2.0.2

* Fix generating mismatched TracingContexts preventing correlation between APM and RUM.

## 2.0.1

* Add GraphQL errors to resource events.
* Catch errors on tracing header creation. See [#979](https://github.com/DataDog/dd-sdk-flutter/issues/979)

## 2.0.0

* Support RUM context in trace headers.
* Support consistent sampling based on session ID.
* Support deterministic sampling decisions on distributed traces.

## 1.2.0

* Fix `GqlErrors` causing an `ArgumentError` on `stopResource`. See [#850](https://github.com/DataDog/dd-sdk-flutter/issues/850)
* Add configurable trace header injection.

* Add support for `TraceContextInjection` configuration.

## 1.1.1

* Fix an exception when attempting to `jsonEncode` unencodable variables.

## 1.1.0

* Support 128-bit trace ids in distributed tracing.

## 1.0.1

* Constrain compatible `datadog_flutter_plugin` to <2.5.0

## 1.0.0

* Initial release of datadog_gql_link
