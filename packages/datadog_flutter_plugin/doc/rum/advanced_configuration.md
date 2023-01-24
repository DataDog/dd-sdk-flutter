# RUM Flutter Advanced Configuration

## Overview

If you have not set up the Datadog Flutter SDK for RUM yet, follow the [in-app setup instructions][1] or refer to the [RUM Flutter setup documentation][2].

## Enrich user sessions

Flutter RUM automatically tracks attributes such as user activity, views (using the `DatadogNavigationObserver`), errors, native crashes, and network requests (using the Datadog Tracking HTTP Client). See the [RUM Data Collection documentation][3] to learn about the RUM events and default attributes. You can further enrich user session information and gain finer control over the attributes collected by tracking custom events.

### Add your own performance timing

In addition to RUM’s default attributes, you can measure where your application is spending its time by using `DdRum.addTiming`. The timing measure is relative to the start of the current RUM view. 

For example, you can time how long it takes for your hero image to appear:

```dart
void _onHeroImageLoaded() {
    DatadogSdk.instance.rum?.addTiming("hero_image");
} 
```

Once you set the timing, it is accessible as `@view.custom_timings.<timing_name>`. For example, `@view.custom_timings.hero_image`. 

To create visualizations in your dashboards, [create a measure][4] first.

### Track user actions

You can track specific user actions such as taps, clicks, and scrolls using `DdRum.addUserAction`. 

To manually register instantaneous RUM actions such as `RumUserActionType.tap`, use `DdRum.addUserAction()`. For continuous RUM actions such as `RumUserActionType.scroll`, use `DdRum.startUserAction()` or `DdRum.stopUserAction()`.

For example:

```dart
void _downloadResourceTapped(String resourceName) {
    DatadogSdk.instance.rum?.addUserAction(
        RumUserActionType.tap,
        resourceName,
    );
}
```

When using `DdRum.startUserAction` and `DdRum.stopUserAction`, the `type` action must be the same in order for the Datadog Flutter SDK to match an action's start with its completion.

### Track custom resources

In addition to tracking resources automatically using the [Datadog Tracking HTTP Client][5], you can track specific custom resources such as network requests or third-party provider APIs using the [following methods][6]:

- `DdRum.startResourceLoading`
- `DdRum.stopResourceLoading`
- `DdRum.stopResourceLoadingWithError`
- `DdRum.stopResourceLoadingWithErrorInfo`

For example:

```dart
// in your network client:

DatadogSdk.instance.rum?.startResourceLoading(
    "resource-key", 
    RumHttpMethod.get,
    url,
);

// Later

DatadogSdk.instance.rum?.stopResourceLoading(
    "resource-key",
    200,
    RumResourceType.image
);
```

The `String` used for `resourceKey` in both calls must be unique for the resource you are calling in order for the Datadog iOS SDK to match a resource's start with its completion.

### Track custom errors

To track specific errors, notify `DdRum` when an error occurs with the message, source, exception, and additional attributes.

```dart
DatadogSdk.instance.rum?.addError("This is an error message.");
```

## Track custom global attributes

In addition to the [default RUM attributes][3] captured by the Datadog Flutter SDK automatically, you can choose to add additional contextual information (such as custom attributes) to your RUM events to enrich your observability within Datadog. 

Custom attributes allow you to filter and group information about observed user behavior (such as the cart value, merchant tier, or ad campaign) with code-level information (such as backend services, session timeline, error logs, and network health).

### Set a custom global attribute

To set a custom global attribute, use `DdRum.addAttribute`.

* To add or update an attribute, use `DdRum.addAttribute`.
* To remove the key, use `DdRum.removeAttribute`.

### Track user sessions

Adding user information to your RUM sessions makes it easy to:

* Follow the journey of a given user
* Know which users are the most impacted by errors
* Monitor performance for your most important users

{{< img src="real_user_monitoring/browser/advanced_configuration/user-api.png" alt="User API in the RUM UI" style="width:90%" >}}

The following attributes are **optional**, provide **at least** one of them:

| Attribute | Type   | Description                                                                                              |
|-----------|--------|----------------------------------------------------------------------------------------------------------|
| `usr.id`    | String | Unique user identifier.                                                                                  |
| `usr.name`  | String | User friendly name, displayed by default in the RUM UI.                                                  |
| `usr.email` | String | User email, displayed in the RUM UI if the user name is not present. It is also used to fetch Gravatars. |

To identify user sessions, use `DdRum.setUserInfo`. 

For example:

```dart
DatadogSdk.instance.setUserInfo("1234", "John Doe", "john@doe.com");
```

## Further reading

{{< partial name="whats-next/whats-next.html" >}}

[1]: https://app.datadoghq.com/rum/application/create
[2]: https://docs.datadoghq.com/real_user_monitoring/flutter/#setup
[3]: https://docs.datadoghq.com/real_user_monitoring/flutter/data_collected
[4]: https://docs.datadoghq.com/real_user_monitoring/explorer/?tab=measures#setup-facets-and-measures
[5]: https://github.com/DataDog/dd-sdk-flutter/tree/main/packages/datadog_tracking_http_client
[6]: https://pub.dev/documentation/datadog_flutter_plugin/latest/datadog_flutter_plugin/