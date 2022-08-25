# Overview

The Datadog Flutter SDK generates events that have associated metrics and attributes. Metrics are quantifiable values that can be used for measurements related to the event. Attributes are non-quantifiable values used to slice metrics data (group by) in analytics.

Every RUM event has all of the default attributes, for example, the device type (device.type) and user information such as their name (usr.name) and their country (geo.country).

There are additional metrics and attributes that are specific to a given event type. For example, the metric view.time_spent is associated with "view" events and the attribute resource.method is associated with "resource" events.

Much of the data is collected by the RUM iOS and RUM Android Native SDKs, and follows the same retention periods, so please see the documentation for the Native SDKs for a complete overview.
    
    * [RUM iOS SDK Data Collected][1]
    * [RUM Android SDK Data Collected][2]


[1]: https://docs.datadoghq.com/real_user_monitoring/ios/data_collected/
[2]: https://docs.datadoghq.com/real_user_monitoring/android/data_collected/