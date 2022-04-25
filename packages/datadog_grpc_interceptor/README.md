
# Datadog gRPC Interceptor / Plugin

> A plugin for use with the `DatadogSdk`, used to track performance of gRPC and enable Datadog Distributed Tracing.

> ⚠️ This plugin is still in Alpha / Developer Preview. 

## Getting started

To utilize this plugin, create an instance of `DatadogGrpcInterceptor`, then pass it to your generated gRPC client:

```dart
import 'package:datadog_grpc_interceptor/datadog_grpc_interceptor.dart'

// Initialize Datadog, be sure to set the [DdSdkConfiguration.firstPartyHosts] member
// to enable Datadog Distributed Tracing
final config = DdSdkConfiguration(
  // ...
  firstParthHosts = ['localhost']
)

// Create the gRPC channel
final channel = ClientChannel(
  'localhost',
  port: 50051,
  options: ChannelOptions(
    // ...
  ),
);

// Create the gRPC interceptor with the supported channel
final datadogInterceptor = DatadogGrpcInterceptor(DatadogSdk.instance, channel);

// Create the gRPC client, passing in the Datadog interceptor
final stub = GreeterClient(channel, interceptors: [datadogInterceptor]);
```

# Contributing

Pull requests are welcome. First, open an issue to discuss what you would like
to change. For more information, read the [Contributing
guide](../../CONTRIBUTING.md) in the root repository.

## Generating the test gRPC files

If you are working on tests for this package and need to regenerate the gRPC client and related code,
follow the instructions on the [gRPC Quick Start](https://grpc.io/docs/languages/dart/quickstart/) page.

The protobuf spec is held in `test/protos/helloworld.proto`

# License

[Apache License, v2.0](LICENSE)
