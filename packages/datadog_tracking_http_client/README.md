
# Datadog Tacking Http Client Plugin

> A plugin for use with the DatadogSdk, used to track performance of http calls and enable Datadog Distributed Tracing.

> ⚠️ This plugin is still in Alpha / Developer Preview. 

## Getting started

To utilize this plugin, simply enable it during configuration of your SDK:

```dart
import 'package:datadog_tracking_http_client/datadog_tracing_http_client.dart'

final DdSdkConfiguration(
  // configuration
)..enableHttpTracking()
```

# Contributing

Pull requests are welcome. First, open an issue to discuss what you would like
to change. For more information, read the [Contributing
guide](../../CONTRIBUTING.md) in the root repository.

# License

[Apache License, v2.0](LICENSE)