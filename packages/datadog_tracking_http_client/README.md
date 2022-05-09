
# Datadog Tracking HTTP Client Plugin

> A plugin for use with the Datadog SDK, used to track performance of HTTP calls and enable Datadog Distributed Tracing.

## Getting started

To use this plugin, enable it during configuration of your SDK. In order to enable Datadog Distributed Tracing, you will also need to set the `firstPartyHosts` property in your configuration object.

```dart
import 'package:datadog_tracking_http_client/datadog_tracing_http_client.dart';

final configuration = DdSdkConfiguration(
  // configuration
  firstPartyHosts: ['example.com'],
)..enableHttpTracking()
```


# Contributing

Pull requests are welcome. First, open an issue to discuss what you would like
to change. For more information, read the [Contributing
guide](../../CONTRIBUTING.md) in the root repository.

# License

[Apache License, v2.0](LICENSE)