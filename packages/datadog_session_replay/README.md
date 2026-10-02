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
dependencies:
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
    clientToken: '<client-token>',
    env: '<env-name>',
    site: DatadogSite.us1,
    // RUM is required to use Datadog Session Replay
    rumConfiguration: DatadogRumConfiguration(
        applicationId: '<application-id>',
    ),
)..enableSessionReplay(
    DatadogSessionReplayConfiguration(
        // Setup default text, image, and touch privacy
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        touchPrivacyLevel: TouchPrivacyLevel.show,
        // Percentage (0-100) of RUM sessions that get a replay. 1.0 records 1%.
        replaySampleRate: 1.0,
    ),
);
```

### Sampling

`replaySampleRate` is the percentage of RUM sessions that get a replay. It applies on top of the RUM `sessionSamplingRate`, because Session Replay can only record sessions that RUM tracks. For example, with RUM at 50% and Session Replay at 20%, about 10% of all sessions have a replay.

The decision is made for each RUM session, from its session ID:

* It is deterministic: the same session ID always gets the same decision, matching the other Datadog SDKs. In a hybrid app, Flutter and the native host agree on which sessions are recorded.
* It is made again whenever a new RUM session starts during the same app launch, for example after 15 minutes of inactivity or after a session reaches 4 hours.

When Flutter is embedded in a native host app (`isEmbedded: true`), `replaySampleRate` is ignored: the native Session Replay's sample rate decides which sessions are recorded.

### Manual start and stop

By default, Session Replay starts recording when it initializes. To start recording manually, set `startRecordingImmediately: false` on `DatadogSessionReplayConfiguration`. Then, call `DatadogSessionReplay.instance!.startRecording()` to begin recording and `DatadogSessionReplay.instance!.stopRecording()` to pause it. The background processor isolate stays running while recording is stopped, so resuming is fast.

Recording only happens while the current RUM session is selected by `replaySampleRate`. If you call `startRecording()` during a session that was not selected, nothing is captured until a selected session starts, and recording then begins on its own. `stopRecording()` stays in effect across session changes. `DatadogSessionReplay.instance!.isCapturing` tells you whether capture is running right now.

Calling `stopRecording()` also stops pointer capture (touch and gesture events). Both resume on the next `startRecording()` call.

```dart
// Begin capturing when the user reaches a screen you want recorded
DatadogSessionReplay.instance!.startRecording();

// Pause capture (for example, before showing a sensitive screen)
DatadogSessionReplay.instance!.stopRecording();
```

For a complete app that uses sampling and manual start and stop, see the [Session Replay example](../../examples/session_replay_example).

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
 
