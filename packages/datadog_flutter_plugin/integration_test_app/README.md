# integration_test_app

This app runs various integration scenarios for the Datadog Flutter SDK

## Running Mobile Tests

Mobile tests can be run with the regular `flutter test` command:

```bash
flutter test integration_test -d "iPhone"
```

The above example will run all integration tests on a device matching the name "iPhone" if one is already booted

## Running Web Tests

Running tests for Flutter web requires a few extra steps, partially outlined in the official [Flutter documentation](https://docs.flutter.dev/cookbook/testing/integration/introduction#5b-web).
However, instead of downloading a version of chromedriver, one is provided in the repository in `tools`.

First, run `chromedriver` on the proper port:
```bash
chromedriver --port=4444
```

Next, you can run one of the web integration tests using the `flutter drive` command:

```bash
flutter drive --driver=test_driver/interation_test.dart --target=integration_test/logging_test.dart -d "Chrome"
```

Each integration test must be run individually.