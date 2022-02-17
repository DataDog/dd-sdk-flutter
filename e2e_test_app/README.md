# e2e_test_app

This app runs various E2E tests for the Datadog Flutter SDK

Datadog E2E tests produce data sent to the Datadog integration environment, and
are checked using Datadog's alerting and monitoring features to inform us if any
features are producing too much data, producing the wrong type of data, or
exhibiting poor performance.

Each test has associated monitors that are defined by the comments above the
test. These are parsed by the `e2e_generator` in the tools directory

# Note
Because Flutter integration tests do not reboot the app in between tests in the
same file, each file starts initializing by initializing the Datadog SDK, then
each test runs "main" for the main application, which purposefully does not
initialize the Datadog SDK.