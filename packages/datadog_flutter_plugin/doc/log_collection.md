# Flutter Log Collection

Send logs to Datadog from your Flutter applications with [Datadog's flutter plugin][1] and leverage the following features:

* Log to Datadog in JSON format natively.
* Use default and add custom attributes to each log sent.
* Record real client IP addresses and User-Agents.
* Leverage optimized network usage with automatic bulk posts.

## Setup

Follow the setup instructions from the [common setup documentation](./common_setup.md).

## Send Logs

After initializing Datadog with a `LoggingConfiguration`, you can use the default instance of `logs` to send logs to Datadog.

```dart
DatadogSdk.instance.logs?.debug("A debug message.");
DatadogSdk.instance.logs?.info("Some relevant information?");
DatadogSdk.instance.logs?.warn("An important warning…");
DatadogSdk.instance.logs?.error("An error was met!");
```

You can also create additional loggers with the `createLogger` method:

```dart
final myLogger = DatadogSdk.instance.createLogger(
  LoggingConfiguration({
    loggerName: 'Additional logger'
  })
);

myLogger.info('Info from my additional logger.');
```

For more information on the options available for loggers, see the [LoggingConfiguration documentation][2]

## Tags and Attributes

### Add Tags

Use the `DdLogs.addTag` method to add tags to all logs sent by a specific logger:

```dart
// This adds a tag "build_configuration:debug"
logger.addTag("build_configuration", "debug")
```

### Remove Tags

Use the `DdLogs.removeTag` method to remove tags from all logs sent by a specific logger:

```dart
// This removes any tag starting with "build_configuration"
logger.removeTag("build_configuration")
```

[Learn more about Datadog tags][3].

### Add attributes

By default, the following attributes are added to all logs sent by a logger:

* `http.useragent` and its extracted `device` and `OS` properties
* `network.client.ip` and its extracted geographical properties (`country`, `city`)
* `logger.version`, Datadog SDK version
* `logger.thread_name`, (`main`, `background`)
* `version`, client's app version extracted from either the `Info.plist` or `application.manifest`
* `environment`, the environment name used to initialize the SDK

Use the `DdLogs.addAttribute` method to add a custom attribute to all logs sent by a specific logger:

```dart
logger.addAttribute("user-status", "unregistered")
```

**Note**: `value` can be most types supported by the `StandardMessageCodec`l

##### Remove attributes

Use the `DdLogs.removeAttribute` method to remove a custom attribute from all logs sent by a specific logger:

```dart
// This removes the attribute "user-status" from all further log send.
logger.removeAttribute("user-status")
```

## Further Reading

{{< partial name="whats-next/whats-next.html" >}}

Tags and attributes set on loggers are local to each logger.


[1]: https://pub.dev/packages/datadog_flutter_plugin
[2]: https://pub.dev/documentation/datadog_flutter_plugin/latest/datadog_flutter_plugin/LoggingConfiguration-class.html
[3]: https://docs.datadoghq.com/tagging/
