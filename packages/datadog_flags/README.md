# Datadog Flags for Flutter

`datadog_flags` is a Dart-native Flutter client for Datadog feature flags. It
fetches precomputed assignments from Datadog, resolves typed values locally, and
reports RUM feature flag evaluations, exposures, and evaluation metrics.

This package does not bridge to native iOS or Android flagging SDKs.

## Setup

Initialize the Datadog Flutter SDK first, then enable flags:

```dart
await DatadogSdk.instance.initialize(configuration, TrackingConsent.granted);
await DatadogFlags.enable();

final flags = DatadogFlags.sharedClient();
await flags.setEvaluationContext(const DatadogFlagsEvaluationContext(
  targetingKey: 'user-123',
  attributes: {'plan': 'pro'},
));
```

## Typed Evaluation

Use typed getters for values or details:

```dart
final enabled = flags.getBooleanValue(
  key: 'checkout.enabled',
  defaultValue: false,
);

final title = flags.getStringDetails(
  key: 'checkout.title',
  defaultValue: 'Checkout',
);
```

Details include the resolved value, variation key, reason, and any evaluation
error:

- `providerNotReady`: no evaluation context has been loaded.
- `flagNotFound`: the current precomputed assignments do not include the flag.
- `typeMismatch`: the assignment type does not match the typed getter.

## Behavior

- Assignments are fetched from `/precompute-assignments`.
- Values are resolved synchronously after `setEvaluationContext` completes.
- Last-known assignments are persisted and restored only when the cached context
  matches the active context.
- Gov sites fall back to the US1 flags endpoint.
- Exposures are sent only for successful typed evaluations where `doLog` is
  true, deduped by `targetingKey + flagKey + allocationKey + variationKey`.
- Evaluation metrics aggregate successful, defaulted, and error evaluations and
  flush on `flush()` or the configured interval.

## Local Validation

From this package:

```bash
dart analyze .
flutter test test
flutter test --platform chrome test
```

The example app includes a local fixture mode for iOS, Android, and web:

```bash
cd ../../examples/simple_example
flutter test integration_test/flags_dogfood_test.dart -d <ios-simulator> --dart-define FLAGS_MODE=local
flutter test integration_test/flags_dogfood_test.dart -d <android-emulator> --dart-define FLAGS_MODE=local
flutter test --platform chrome test/flags_dogfood_web_test.dart --dart-define FLAGS_MODE=local
```
