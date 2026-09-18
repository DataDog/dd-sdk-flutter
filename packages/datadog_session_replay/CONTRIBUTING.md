# Contributing

## General information

For general information about contributing to any of the Datadog Flutter packages, please see the `CONTRIBUTING` document at the [root of the repository](../../CONTRIBUTING.md). It contains all the basic guidance on how to get started will all of the packages including `melos` commands and code style information.

## Working with FFI Code

The Session Replay plugin uses FFI over Method Channels in order to better utilize multiple isolates and multiple threads, instead of having to pass through the Flutter main thread for each message.  We generate our FFI bridges using `ffigen` and `jnigen` when the platform interfaces change.

`ffigen` and `jnigen` configurations are held in separate files from the `pubspec.yaml`.

### Regenerating iOS FFI Interfaces

The bridge between Dart and iOS is held in `ios/datadog_session_replay/Sources/FlutterSessionReplayBridge.swift`

To make a change to the iOS FFI interface, you first have to generate a "bridging header" from the Swift code. You can do this by building the Swift package held at [`ios/datadog_session_replay`](./ios/datadog_session_replay/).

```bash
swift build
```

This build will fail, but that's okay. It will still output the necessary bridging header at `ios/datadog_session_replay/Sources/datadog_session_replay_bridge.swift`.

The next step is to regenerate the FFI bindings from the bridging header using the `dart ffigen` command at the root of the pacakage

```bash
dart run ffigen --config ffigen_ios.yaml
```

### Regenerating Andoird FFI Interface

The bridge between Dart and Android is held in `android/src/main/kotlin/com/datadoghq/flutter/sessionreplay/FlutterSessionReplayBridge.kt`.

If you make a change to this interface, you will need to regenerate the Dart bridge from JNI. You can do this first building the example APK:

```bash
# From ./examples
flutter build apk
```

Then, run jnigen:

```bash
# From the root
dart run jnigen --config jnigen.ysml
```

## Golden Tests

Flutter Session Replay uses "golden testing" to try to ensure that the SR wireframes remain consistent and are a reasonable representation of the widgets we capture. Each golden test captures a widget tree as SR wireframes, then renders the resulting wireframes using a Flutter `CustomPainter` called `WireframeCustomPainter`. The resulting render is captured and compared known good, "golden" image held in `example/golden_test/goldens`. This also allows us to look at the results of simple widget captures without needing to send them to Datadog intake for verification.

To write a new Golden test, follow the examples in `example/golden_test/simple_widget_golden_test.dart`.

If you are making changes and need to test that you have not broken anything in the golden tests, you can run:

```bash
# from ./example
flutter test golden_test
```

If you have made changes that require updating the golden images, run:

```bash
# from ./example
flutter test golden_test --update-goldens
```
