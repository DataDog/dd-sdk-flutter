# Migration from 3.x to 4.0

## Flutter Web Changes

Clients using Flutter Web should update to using the Datadog Browser SDK v7. Change the following import in your `index.html`:

```diff
-  <script type="text/javascript" src="https://www.datadoghq-browser-agent.com/us1/v6/datadog-logs.js"></script> 
-  <script type="text/javascript" src="https://www.datadoghq-browser-agent.com/us1/v6/datadog-rum-slim.js"></script> 
+  <script type="text/javascript" crossorigin="anonymous" src="https://www.datadoghq-browser-agent.com/us1/v7/datadog-logs.js"></script>
+  <script type="text/javascript" crossorigin="anonymous" src="https://www.datadoghq-browser-agent.com/us1/v7/datadog-rum-slim.js"></script>
```

The v7 CDN bundles use ESM dynamic imports to load async chunks, so the `crossorigin="anonymous"` attribute is now required on the script tags.

If you allowlist cookies (for example in a content security policy or proxy), add `_dd_s_v2` alongside the existing `_dd_s` cookie name; the Browser SDK migrates sessions from `_dd_s` automatically on first load, but rolling back to v6 afterwards will start a new session.

If you use `firstPartyHosts` with tracing headers, the Browser SDK now sends an additional `baggage` header by default. If your server's CORS configuration restricts `Access-Control-Allow-Headers`, add `baggage` to the allowlist.

# Migration from 2.x to 3.0

## Android Changes

Clients using Kotlin should update their Kotlin version to 2.1.0+. Flutter versions above 3.27 warn that older versions of Kotlin will not be supported, and provide instructions for updating.

Clients using Flutter before 3.27 will need to manually update their Android `compileSdkVersion` to be 35+ and their `minSdkVersion` to 23+.

Flutter updated the `flutter.compileSdkVersion` variable to 35 in 3.27, so this change is unnecessary for clients using Flutter versions greater than that.

## Flutter Web Changes

Clients using Flutter Web should update to using the Datadog Browser SDK v6.  Change the following import in your `index.html`:

```diff
-  <script type="text/javascript" src="https://www.datadoghq-browser-agent.com/us1/v5/datadog-logs.js"></script> 
-  <script type="text/javascript" src="https://www.datadoghq-browser-agent.com/us1/v5/datadog-rum-slim.js"></script> 
+  <script type="text/javascript" src="https://www.datadoghq-browser-agent.com/us1/v6/datadog-logs.js"></script> 
+  <script type="text/javascript" src="https://www.datadoghq-browser-agent.com/us1/v6/datadog-rum-slim.js"></script> 
```

# RUM Changes

An ID is no longer optional in `setUserInfo`. If you need to clear user info, use `clearUserInfo` instead.

The default trace sampling rate (`DatadogRumConfiguration.traceSampleRate` and `DatadogAttachConfiguration.traceSampleRate`) has changed from 20% to 100%.

# Migration from 1.x to 2.0

This document describes the main changes introduced in SDK `2.0` compared to `1.x`.

## SDK Configuration Changes

Certain configuration properties have been moved or renamed to support modularity in Datadog's native SDKs.

The following structures have been renamed

| `1.x` | `2.x` |
| `DdSdkConfiguration` | `DatadogConfiguration` |
| `LoggingConfiguartion` | `DatadogLoggingConfiguration` |
| `RumConfiguration` | `DatadogRumConfiguration` |
| `DdSdkExistingConfiguration` | `DatadogAttachConfiguration` |

The following properties have changed:

| `1.x` | `2.x` | Notes |
|-------|-------|-------|
| `DdSdkConfiguration.trackingConsent`| Removed | Part of `Datadog.initialize` | | 
| `DdSdkConfiguration.customEndpoint` | Removed | Now configured per-feature | |
| `DdSdkConfiguration.serviceName` | `DatadogConfiguration.service` | |
| `DdSdkConfiguration.logEventMapper` | `DatadogLoggingConfiguration.eventMapper` | |
| `DdSdkConfiguration.customLogsEndpoint` | `DatadogLoggingConfiguration.customEndpoint` | |
| `DdSdkConfiguration.telemetrySampleRate` | `DatadogRumConfiguration.telemetrySampleRate` | |

In addition, the following APIs have changed:

| `1.x` | `2.x` | Notes |
|-------|-------|-------|
| `Verbosity` | Removed | See `CoreLoggerLevel` or `LogLevel` | 
| `DdLogs DatadogSdk.logs` | `DatadogLogging DatadogSdk.logs` | Type changed |
| `DdRum DatadogSdk.rum` | `DatadogRum DatadogSdk.rum` | Type changed
| `Verbosity DatadogSdk.sdkVerbosity` | `CoreLoggerLevel DatadogSdk.sdkVerbosity` |
| `DatadogSdk.runApp` | `DatadogSdk.runApp` | Added `trackingConsent` parameter |
| `DatadogSdk.initialize` | `DatadogSdk.initialize` | Added `trackingConsent` parameter |
| `DatadogSdk.createLogger` | `DatadogLogging.createLogger` | Moved |

## Flutter Web Changes

Clients using Flutter Web should update to using the Datadog Browser SDK v5.  Change the following import in your `index.html`:

```diff
-  <script type="text/javascript" src="https://www.datadoghq-browser-agent.com/datadog-logs-v4.js"></script>
-  <script type="text/javascript" src="https://www.datadoghq-browser-agent.com/datadog-rum-slim-v4.js"></script>
+  <script type="text/javascript" src="https://www.datadoghq-browser-agent.com/us1/v5/datadog-logs.js"></script> 
+  <script type="text/javascript" src="https://www.datadoghq-browser-agent.com/us1/v5/datadog-rum-slim.js"></script> 
```
 
Note that Datadog provides one CDN bundle per site. See the [Browser SDK README](https://github.com/DataDog/browser-sdk/#cdn-bundles) for a list of all site URLs.

## Logs Product Changes

As with `1.x`, Datadog Logging can be enabled by setting the `DatadogConfiguration.loggingConfiguration` member. However, unlike `1.x`, Datadog will not create a default logger for you. `DatadogSdk.logs` is now and instance of `DatadogLogging`, which can be used to create logs. Many options were moved to `DatadogLoggerConfiguration` to give developers more granular support over individual loggers.

The following APIs have changed:

| `1.x` | `2.x` | Notes |
|-------|-------|-------|
| `LoggingConfiguration` | `DatadogLoggingConfiguration` | Rename, most members are now on `DatadogLoggerConfiguration` |
| `LoggingConfiguration.sendNetworkInfo` | `DatadogLoggerConfiguration.networkInfoEnabled` | |
| `LoggingConfiguration.printLogsToConsole` | `DatadogLoggerConfiguration.customConsoleLogFunction` | |
| `LoggingConfiguration.sendLogsToDatadog` | Removed. Use `remoteLogThreshold` instead | |
| `LoggingConfiguration.datadogReportingThreshold` | `DatadogLoggerConfiguration.remoteLogThreshold` | |
| `LoggingConfiguration.bundleWithRum` | `DatadogLoggerConfiguration.bundleWithRumEnabled` | |
| `LoggingConfiguration.bundleWithTrace` | `DatadogLoggerConfiguration.bundleWithTraceEnabled` | |
| `LoggingConfiguration.loggerName` | `DatadogLoggerConfiguration.name` | | 
| `LoggingConfiguration.sampleRate` | `DatadogLoggerConfiguration.remoteSampleRate` | |

## RUM Product Changes

The following APIs have changed:

| `1.x` | `2.x` | Notes |
|-------|-------|-------|
| `RumConfiguration` | `DatadogRumConfiguration` | Type renamed |
| `RumConfiguration.vitalsUpdateFrequency` | `DatadogRumConfiguration.vitalsUpdateFrequency` | Set to `null` to disable vitals updates |
| `RumConfiguration.tracingSampleRate` | `DatadogRumConfiguration.traceSampleRate` |
| `RumConfiguration.rumViewEventMapper` | `DatadogRumConfiguration.viewEventMapper` |
| `RumConfiguration.rumActionEventMapper` | `DatadogRumConfiguration.actionEventMapper` |
| `RumConfiguration.rumResourceEventMapper` | `DatadogRumConfiguration.resourceEventMapper` |
| `RumConfiguration.rumErrorEventMapper` | `DatadogRumConfiguration.rumErrorEventMapper` |
| `RumConfiguration.rumLongTaskEventMapper` | `DatadogRumConfiguration.longTaskEventMapper` |
| `RumUserActionType` | `RumActionType` | Type renamed | 
| `DdRum.addUserAction` | `DdRum.addAction` | | 
| `DdRum.startUserAction` | `DdRum.startAction` | | 
| `DdRum.stopUserAction` | `DdRum.stopAction` | | 
| `DdRum.startResourceLoading` | `DdRum.startResource` | | 
| `DdRum.stopResourceLoading` | `DdRum.stopResource` | | 
| `DdRum.stopResourceLoadingWithError` | `DdRum.stopResourceWithError` | | 

Additionally, event mappers no longer allow you to modify their view names. To rename a view, use a custom [`ViewInfoExtractor`](https://pub.dev/documentation/datadog_flutter_plugin/latest/datadog_flutter_plugin/ViewInfoExtractor.html) instead.

