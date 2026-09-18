
# Datadog Dio integration

> A package for use with Dio and the Datadog SDK, used to track performance of HTTP calls and enable Datadog Distributed Tracing.

## Getting started

To use the Datadog Dio Interceptor, call `addDatadogInterceptor` on your Dio object:

```dart
import 'package:datadog_dio/datadog_dio.dart'

Dio dio = Dio()
  // Other Dio configuration...
  ..addDatadogInterceptor(DatadogSdk.instance);
```

In order to enable Datadog Distributed Tracing, you also need to set the `firstPartyHosts` property when configuring Datadog.

```dart
import 'package:datadog_tracking_http_client/datadog_tracking_http_client.dart';

final configuration = DatadogConfiguration(
  // configuration
  firstPartyHosts: ['example.com'],
)
```

## Use with other Dio interceptors

`addDatadogInterceptor` adds the Datadog interceptor as the first interceptor in your list of interceptors, which is important to ensure that all network requests from Dio are sent to Datadog, as other interceptors may decide not to forward information down the interceptor chain. For this reason, it is important to make sure you call `addDatadogInterceptor` after any other configuration of Dio is complete.

## Use with other Datadog Network Tracking

Clients that want to track all network requests, including those made by `dart:io` and widgets like `NetworkImage` can continue to use [`datadog_tracking_http_client`](https://pub.dev/packages/datadog_tracking_http_client) to capture these requests. However, depending on your setup, the global overide method used in `enableHttpTracking` may cause resources to be double reported (once by the global override and once by the Dio interceptor).

To avoid this, we recommend using `ignoreUrlPatterns` parameter when calling `enableHttpTracking` to ignore requests made by your Dio client.

# Contributing

Pull requests are welcome. First, open an issue to discuss what you would like
to change. For more information, read the [Contributing
guide](../../CONTRIBUTING.md) in the root repository.

# License

[Apache License, v2.0](LICENSE)