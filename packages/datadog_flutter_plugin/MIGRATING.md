# Migration from 1.x to 2.0

This document describes the main changes introduced in SDK `2.0` compared to `1.x`.

## SDK Configuration Changes

Certain configuration properties have been moved or renamed to support modularity in Datadog's native SDKs.

The following structures have been renamed

| `1.x` | `2.x` |
| `DdSdkConfiguration` | `DatadogConfiguration` |
| `LoggingConfiguartion` | `DatadogLoggingConfiguration` |
| `RumConfiguration` | `DatadogRumConfiguration` |

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
 

# Logs Product Changes

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

# RUM Product Changes

The following APIs have changed:

| `1.x` | `2.x` | Notes |
|-------|-------|-------|
| `RumConfiguration` | `DatadogRumConfiguration` | Type renamed |
| `RumConfiguration.vitalsUpdateFrequency` | `DatadogRumConfiguration.vitalsUpdateFrequency` | Set to `null` to disable vitals updates |
| `RumConfiguration.rumViewEventMapper` | `DatadogRumConfiguration.viewEventMapper` |
| `RumConfiguration.runActionEventMapper` | `DatadogRumConfiguration.actionEventMapper` |
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

