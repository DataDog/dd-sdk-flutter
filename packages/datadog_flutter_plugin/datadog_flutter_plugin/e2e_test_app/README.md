# e2e_test_app

This app runs various E2E tests for the Datadog Flutter SDK

Datadog E2E tests produce data sent to the Datadog integration environment, and
are checked using Datadog's alerting and monitoring features to inform us if any
features are producing too much data, producing the wrong type of data, or
exhibiting poor performance.

Each test has associated monitors that are defined by the comments above the
test. These are parsed by the `e2e_generator` in the tools directory

# Driver

Launching these tests on simulators is done with the standard `flutter test`
command. In the future we would like to run these on device, if possible, in
order to get more accurate performance metrics.

To run on a device, you need to use the `/test_driver/integration_test.dart`
file using the command:

```bash
flutter drive --profile --no-dds --driver=test_driver/integration_test.dart --target=integration_test
```