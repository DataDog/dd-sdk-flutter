<p align="center">
    <img src="https://imgix.datadoghq.com/img/about/presskit/logo-v/dd_vertical_white.png" width="200">
</p>

# DataDog Flutter Plugin Packages

This is the monorepo for Datadog Flutter packages. To get started, check the
[README](packages/datadog_flutter_plugin/README.md) in the core plugin.

## Packages

| Package | Pub | Repo |
| :-----: | :-: | :--: |
| datadog_flutter_plugin | [![Pub](https://img.shields.io/pub/v/datadog_flutter_plugin.svg)](https://pub.dev/packages/datadog_flutter_plugin) | [packages/datadog_flutter_plugin](packages/datadog_flutter_plugin/) | 
| datadog_flags | [![Pub](https://img.shields.io/pub/v/datadog_flags.svg)](https://pub.dev/packages/datadog_flags) | [packages/datadog_flags](packages/datadog_flags/) |
| datadog_flags_flutter | [![Pub](https://img.shields.io/pub/v/datadog_flags_flutter.svg)](https://pub.dev/packages/datadog_flags_flutter) | [packages/datadog_flags_flutter](packages/datadog_flags_flutter/) |
| datadog_tracking_http_client | [![Pub](https://img.shields.io/pub/v/datadog_tracking_http_client.svg)](https://pub.dev/packages/datadog_tracking_http_client) | [packages/datadog_tracking_http_client](packages/datadog_tracking_http_client/) | 
| datadog_webview_tracking | [![Pub](https://img.shields.io/pub/v/datadog_webview_tracking.svg)](https://pub.dev/packages/datadog_webview_tracking) | [packages/datadog_webview_tracking](packages/datadog_webview_tracking/) 
| datadog_grpc_interceptor | [![Pub](https://img.shields.io/pub/v/datadog_grpc_interceptor.svg)](https://pub.dev/packages/datadog_grpc_interceptor) | [packages/datadog_grpc_interceptor](packages/datadog_grpc_interceptor/) | 
| datadog_gql_link | [![Pub](https://img.shields.io/pub/v/datadog_gql_link.svg)](https://pub.dev/packages/datadog_gql_link) | [packages/datadog_gql_link](packages/datadog_gql_link/) | 

## Choose a Feature Flags Integration

Use the OpenFeature provider in `datadog_flags` for new Dart and Flutter
integrations. It is the canonical customer integration.

| Application | Evaluation API | Package |
| --- | --- | --- |
| Dart or Flutter | OpenFeature (recommended) | [`datadog_flags`](packages/datadog_flags/) |
| Flutter with RUM view association | OpenFeature and `DatadogRumHook` | [`datadog_flags_flutter`](packages/datadog_flags_flutter/) |

The provider is part of `datadog_flags`. Add `DatadogRumHook` from
`datadog_flags_flutter` for RUM association. The legacy Datadog evaluation API is
deprecated and is scheduled for removal in the next major version.

# Contributing

Please read the [Contributing Guide](CONTRIBUTING.md)
