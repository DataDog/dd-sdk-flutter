# E2E Generator

This is the Dart library for parsing Datadog Flutter's End to End tests for
Monitor definitions.

Datadog E2E tests produce data sent to the Datadog integration environment, and
are checked using Datadog's alerting and monitoring features to inform us if any
features are producing too much data, producing the wrong type of data, or
exhibiting poor performance.

Monitor definitions are comments above tests and are of the form:
```dart
/// ```monitor_type (logs, apm, rum)
/// $var = variable value
/// $var2 = variable value
/// ```
```

These monitors definitions are turned into Terraform files, which are sent to
Datadog's integration environment to create the monitors and alerts to let us
know if something isn't right

## Usage

To regenerate the Terraform files, run the following command from this directory

```bash
dart ./bin/e2e_generator ../../e2e_test_app/test
```
