# E2E Generator

This is the Dart library for parsing Datadog Flutter's End to End tests for
Monitor definitions.

Datadog E2E tests produce data sent to the Datadog integration environment, and
are checked using Datadog's alerting and monitoring features to inform us if any
features are producing too much data, producing the wrong type of data, or
exhibiting poor performance.

Monitor definitions are comments above tests and are of the form:
```dart
/// ```monitor_type (variant1, variant2)
/// $var = variable value
/// $var2 = variable value
/// ```
```

Valid monitor types are `rum`, `apm` and `logs`

Variants will cause the monitor to be generated multiple times, once for each
supplied variant.

These monitors definitions are turned into Terraform files, which are sent to
Datadog's integration environment to create the monitors and alerts to let us
know if something isn't right

For any given set of monitors you can define a set of global variables that will
be substituted in each monitor by using a `global` monitor definition. This can
be done at the top level of the test file (before `main`) or on each test.
Global monitor definitions are not supported on test groups yet.

There are several predefined variables as well
* `variant` - The variant currently being generated
* `testDescription` - The description of the test this monitor is attached to.

## Usage

To regenerate the Terraform files, run the following command from this directory

```bash
dart ./bin/e2e_generator ../../e2e_test_app/test
```
