
# Datadog Tracking HTTP Client Plugin

> A plugin for use with the Datadog SDK, used to track performance of HTTP calls and enable Datadog Distributed Tracing.

## Getting started

To use this plugin, enable it during configuration of your SDK. In order to enable Datadog Distributed Tracing, you also need to set the `firstPartyHosts` property in your configuration object.

```dart
import 'package:datadog_tracking_http_client/datadog_tracking_http_client.dart';

final configuration = DdSdkConfiguration(
  // configuration
  firstPartyHosts: ['example.com'],
)..enableHttpTracking()
```

## Flutter 2.8 Support

Flutter 3.0 updated to Dart 2.17, which added two methods to HttpClient. 

Currently, `version 1.1.x` sets a version constraint to Dart >= 2.17. If you need to support versions of Flutter prior to 3.0, back to flutter 2.8, use `version 1.0.x` instead. There is no difference between these versions other than support for lower versions of Dart.
  
# Contributing

Pull requests are welcome. First, open an issue to discuss what you would like
to change. For more information, read the [Contributing
guide](../../CONTRIBUTING.md) in the root repository.

# License

[Apache License, v2.0](LICENSE)