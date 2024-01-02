
# Datadog GraphQL Link

> A package for tracking GraphQL calls in Datadog compatible with (`gql_link`)[https://pub.dev/packages/gql_link]

## Getting started

To use the `datadog_gql_link`, add it above your terminating link when using `Link.from` or `Link.concat`. For example:

```dart
final graphQlUrl = "https://example.com/graphql";

final link = Link.from([
  DatadogGqlLink(DatadogSdk.instance, Uri.parse(graphQlUrl)),
  HttpLink(graphQlUrl),
]);
```

If you are using `datadog_gql_link` in conjunciton with
`datadog_tracking_http_client`, you will need to have the tracking plugin ignore
requests to your GraphQL endpoint, otherwise resources will be double reported,
and APM traces may be broken. You can ignore your GraphQL endpoint by using the
`ignoreUrlPatterns` parameter added to `datadog_tracking_http_client` version
2.1.0.

```dart
final datadogConfig = DatadogConfiguration(
    // Your configuration
  )..enableHttpTracking(
      ignoreUrlPatterns: [
        RegExp('example.com/graphql'),
      ],
    );
```


# Contributing

Pull requests are welcome. First, open an issue to discuss what you would like
to change. For more information, read the [Contributing
guide](../../CONTRIBUTING.md) in the root repository.

# License

[Apache License, v2.0](LICENSE)
