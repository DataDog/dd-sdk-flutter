# Datadog Session Replay

> [!WARNING]
> This package is currently in preview! Portions of the public API for this package may break without a major version update.

A package for integrating [Datadog Session Replay](https://www.datadoghq.com/product/real-user-monitoring/session-replay/) into Flutter applications.

## Getting started

Session Replay for Flutter requires using the [Datadog Flutter Plugin](https://pub.dev/packages/datadog_flutter_plugin) in conjunction with Datadog RUM. For more information on how to set up RUM, check the [official documentation](https://docs.datadoghq.com/real_user_monitoring/mobile_and_tv_monitoring/flutter/setup/?tab=rum).

> [!IMPORTANT]
> Flutter Session Replay relies on FFI, and iOS requires a build change that the package cannot change automatically.
> To ensure the required FFI symbols are not stripped during Archiving or IPA creation, you must set `Strip Style` in your Xcode project to `Non-Global Symbols`.
>
> For more information, see [this issue](https://github.com/flutter/flutter/issues/62666) in the Flutter repo.

To use Datadog Session Replay for Flutter, first add the package to your `pubspec.yaml`:

```yaml
packages:
  # other packages
  datadog_flutter_plugin: ^x.x.x
  datadog_session_replay: ^x.x.x
```

Next, add Session Replay to your `DatadogConfiguration`:

```dart
import 'package:datadog_session_replay/datadog_session_replay.dart';

// ....
final configuration = DatadogConfiguration(
    // Normal Datadog configuration
    clientToken: 'client-token',
    // RUM is required to use Datadog Session Replay
    rumConfiguration: RumConfiguration(
        applicationId: '<application-id'>
    ),
)..enableSessionReplay(
    DatadogSessionReplayConfiguration(
        // Setup default text, image, and touch privacy
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        touchPrivacyLevel: TouchPrivacyLevel.show,
        // Setup session replay sample rate.
        replaySampleRate: 1.0,
    ),
);
```

### Manual start and stop

By default, Session Replay starts recording when it initializes. To start recording manually, set `startRecordingImmediately: false` on `DatadogSessionReplayConfiguration`. Then, call `DatadogSessionReplay.instance!.startRecording()` to begin recording and `DatadogSessionReplay.instance!.stopRecording()` to pause it. The background processor isolate stays running while recording is stopped, so resuming is fast.

Calling `stopRecording()` also stops pointer capture (touch and gesture events). Both resume on the next `startRecording()` call.

```dart
// Begin capturing when the user reaches a screen you want recorded
DatadogSessionReplay.instance!.startRecording();

// Pause capture (for example, before showing a sensitive screen)
DatadogSessionReplay.instance!.stopRecording();
```

Last, add a SessionReplayCapture widget to the root of your Widget tree, above your MaterialApp or similar application widget:

```dart
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Note a key is required for SessionReplayCapture
  final captureKey = GlobalKey();

  // Other App Configuration

  @override
  Widget build(BuildContext context) {
    return SessionReplayCapture(
      key: captureKey,
      rum: DatadogSdk.instance.rum!,
      sessionReplay: DatadogSessionReplay.instance!,
      child: MaterialApp.router(color: color, routerConfig: router),
    );
  }
}
```

### Note

`SessionReplayCapture` includes a `RumUserActionDetector`. If you are already using a `RumUserActionDetector`, you should remove it in favor of the one used by `SessionReplayCapture`.

# Documentation

For more information including how to set up fine grained masking and privacy controls, see Datadog's [official documentation](https://docs.datadoghq.com/real_user_monitoring/session_replay/mobile) for Session Replay.

# Contributing

Pull requests are welcome. First, open an issue to discuss what you would like to change. For more information, read the [Contributing guide](../../CONTRIBUTING.md) in the root repository.

# License

[Apache License, v2.0](LICENSE)
 
