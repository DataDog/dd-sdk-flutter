# Datadog Flags integration tests

This app runs the OpenFeature integration test on native and browser targets.
It uses controlled HTTP responses and synthetic credentials. The web intake test
uses the shared recording server from `datadog_common_test`.

Run Melos bootstrap at the repository root, then start a device and run:

```sh
flutter test integration_test/openfeature_test.dart -d <DEVICE_ID>
```

The repository's integration-test targets discover this app on Android, iOS,
macOS, Windows, Linux, and web. See the [validation guide](../../datadog_flags/OPENFEATURE_VALIDATION.md).
