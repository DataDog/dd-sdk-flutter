## 2.2.0

* Capture HTTP request and response headers for RUM resources.

## 2.1.0

* Add RUM resource size tracking for chunked / streamed responses.

## 2.0.0

* Expose `DatadogDioInterceptor`. See [#906](https://github.com/DataDog/dd-sdk-flutter/issues/906)
* Update dio package for v3.

## 1.1.1

* Expose `DatadogDioInterceptor`. See [#906](https://github.com/DataDog/dd-sdk-flutter/issues/906)

## 1.1.0

* Support properly stopping Dio's `badResponse` exceptions.

## 1.0.0

* Initial release.
* Support tracking Dio requests via `Dio.addDatadogInterceptor`.
* Support custom attributes through `DatadogDioAttributeProvider`.
