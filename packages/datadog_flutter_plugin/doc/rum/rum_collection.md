# Flutter Real User Monitoring (RUM)

Datadog Real User Monitoring (RUM) enables you to visualize and analyze the real-time performance and user journeys of your application's individual users.

## Setup

### Specify application details in the UI

1. In the [Datadog app][2], navigate to **UX Monitoring** > **RUM Applications** > **New Application**.
2. Choose `Flutter` as the application type.
3. Provide an application name to generate a unique Datadog application ID and client token.

{{< img src="real_user_monitoring/flutter/image_flutter.png" alt="Create a RUM application in Datadog workflow" style="width:90%;">}}

To ensure the safety of your data, you must use a client token. For more information about setting up a client token, see the [Client Token documentation][3].

### Setup the SDK

Follow the setup instructions from the [common setup documentation](./common_setup.md).

# Automatic View Tracking

The Datadog Flutter Plugin can automatically track named routes using the `DatadogNavigationObserver` on your MaterialApp.

```dart
MaterialApp(
  home: HomeScreen(),
  navigatorObservers: [
    DatadogNavigationObserver(DatadogSdk.instance),
  ],
);
```

This works if you are using named routes or if you have supplied a name to the `settings` parameter of your `PageRoute`.

Alternately, you can use the `DatadogRouteAwareMixin` property in conjunction with the `DatadogNavigationObserverProvider` property to start and stop your RUM views automatically. With `DatadogRouteAwareMixin`, move any logic from `initState` to `didPush`. 

# Automatic Resource Tracking

You can enable automatic tracking of resources and HTTP calls from your RUM views using the [Datadog Tracking HTTP Client][1] package. Add the package to your `pubspec.yaml`, and add the following to your initialization:

```dart
final configuration = DdSdkConfiguration(
  // configuration
  firstPartyHosts: ['example.com'],
)..enableHttpTracking()
```

In order to enable Datadog Distributed Tracing, the `DdSdkConfiguration.firstPartyHosts` property in your configuration object **must** be set to a domain that supports distributed tracing. You can also modify the sampling rate for Datadog distributed tracing by setting the `tracingSamplingRate` on your `RumConfiguration`.

Note that `firstPartyHosts` does not allow wildcards, but will match any subdomains for a given domain, so `api.example.com` will match `staging.api.example.com` and `prod.api.example.com`, but not `news.example.com`.


[1]: https://pub.dev/packages/datadog_tracking_http_client