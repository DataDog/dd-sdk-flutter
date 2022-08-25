# RUM Flutter Advanced Configuration

## Enrich user sessions

Flutter RUM can automatically track attributes such as user activity, views (using the `DatadogNavigaionObserver`), errors, native crashes, and network requests (using Datadog Tracking HTTP Client). See the [RUM Data Collection documentation](data_collected.md) to learn about the RUM events and default attributes. You can further enrich user session information and gain finer control over the attributes collected by tracking custom events.

### Add your own performance timing

In addition to RUM’s default attributes, you can measure where your application is spending its time by using `DdRum.addTiming`. The timing measure is relative to the start of the current RUM view. 

For example, you can time how long it takes for your hero image to appear:

```dart
void _onHeroImageLoaded() {
    DatadogSdk.instance.rum?.addTiming("hero_image");
} 
```

Once you set the timing, it is accessible as `@view.custom_timings.<timing_name>`. For example, `@view.custom_timings.hero_image`. 

To create visualizations in your dashboards, [create a measure][1] first.

### Track User Actions

You can track specific user actions (taps, clicks, and scrolls) with `DdRum.addUserAction`. 

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

**Note**: When using `DdRum.startUserAction` and `DdRum.stopUserAction`, the action `type` must be the same. This is necessary for the RUM Flutter SDK to match an action start with its completion.

### Custom Resources

In addition to tracking resources automatically with Datadog Tracking Http Client, you can also track specific custom resources such as network requests or third-party provider APIs. Using the following methods:

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

**Note**: The `String` used for `resourceKey` in both calls must be unique for the resource you are calling. This is necessary for the RUM iOS SDK to match a resource's start with its completion.

### Custom Errors

To track specific errors, notify `DdRum` when an error occurs with the message, source, exception, and additional attributes.

```dart
DatadogSdk.instance.rum?.addError("error message.");
```

### Track custom global attributes

In addition to the [default RUM attributes](data_collected.md) captured by the RUM Flutter SDK automatically, you can choose to add additional contextual information (such as custom attributes) to your RUM events to enrich your observability within Datadog. 

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

{{< img src="real_user_monitoring/browser/advanced_configuration/user-api.png" alt="User API in the RUM UI"  >}}

The following attributes are **optional**, you should provide **at least one** of them:

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


[1]: https://docs.datadoghq.com/real_user_monitoring/explorer/?tab=measures#setup-facets-and-measures
