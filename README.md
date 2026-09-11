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
| datadog_openfeature_provider | Prerelease pending | [packages/datadog_openfeature_provider](packages/datadog_openfeature_provider/) |
| datadog_tracking_http_client | [![Pub](https://img.shields.io/pub/v/datadog_tracking_http_client.svg)](https://pub.dev/packages/datadog_tracking_http_client) | [packages/datadog_tracking_http_client](packages/datadog_tracking_http_client/) | 
| datadog_webview_tracking | [![Pub](https://img.shields.io/pub/v/datadog_webview_tracking.svg)](https://pub.dev/packages/datadog_webview_tracking) | [packages/datadog_webview_tracking](packages/datadog_webview_tracking/) 
| datadog_grpc_interceptor | [![Pub](https://img.shields.io/pub/v/datadog_grpc_interceptor.svg)](https://pub.dev/packages/datadog_grpc_interceptor) | [packages/datadog_grpc_interceptor](packages/datadog_grpc_interceptor/) | 
| datadog_gql_link | [![Pub](https://img.shields.io/pub/v/datadog_gql_link.svg)](https://pub.dev/packages/datadog_gql_link) | [packages/datadog_gql_link](packages/datadog_gql_link/) | 

## Choose a Feature Flags Integration

Use `datadog_openfeature_provider` for new Dart and Flutter integrations. It is
the canonical customer integration and uses the OpenFeature API.

| Application | Evaluation API | Package |
| --- | --- | --- |
| Dart or Flutter | OpenFeature (recommended) | [`datadog_openfeature_provider`](packages/datadog_openfeature_provider/) |
| Dart with low-level lifecycle control | Datadog | [`datadog_flags`](packages/datadog_flags/) |
| Flutter with automatic RUM view association | Datadog | [`datadog_flags_flutter`](packages/datadog_flags_flutter/) |

The OpenFeature provider uses the pure-Dart `datadog_flags` runtime. It does
not use `datadog_flags_flutter` or add evaluations to the active Flutter RUM
view.

# Contributing

Please read the [Contributing Guide](CONTRIBUTING.md)
