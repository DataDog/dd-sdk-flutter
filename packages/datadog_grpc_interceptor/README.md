
# Datadog gRPC Interceptor / Plugin

> A plugin for use with the DatadogSdk, used to track performance of gRPC and enable Datadog Distributed Tracing.

> ⚠️ This plugin is still in Alpha / Developer Preview. 

## Getting started

To utilize this plugin, create an instance of `DatadogGrpcInterceptor`, then pass it to your generated gRPC client:

```dart
import 'package:datadog_grpc_interceptor/datadog_grpc_interceptor.dart'

// Initialize Datadog
// ... 

// Create the gRPC interceptor
final datadogInterceptor = DatadogGrpcInterceptor(DatadogSdk.instance);

// Create the gRPC channel and client, passing in the Datadog interceptor
final channel = ClientChannel(
  'localhost',
  port: 50051,
  options: ChannelOptions(
    // ...
  ),
);
final stub = GreeterClient(channel, interceptors: [datadogInterceptor]);
```

# Contributing

Pull requests are welcome. First, open an issue to discuss what you would like
to change. For more information, read the [Contributing
guide](../../CONTRIBUTING.md) in the root repository.

# License

[Apache License, v2.0](LICENSE)