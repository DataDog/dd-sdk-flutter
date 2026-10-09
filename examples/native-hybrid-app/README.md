# Datadog Flutter Plugin: Hybrid Session Replay example

This example shows Session Replay in a hybrid (add-to-app) app: a native iOS or
Android app that embeds Flutter content. The native Session Replay records the
whole app, and the Flutter content shows up in the same replay, where it sits
on screen.

It covers two common ways to embed Flutter:

* **An embedded panel**: A Flutter view in the middle of a native screen,
  between native controls (`embeddedMain` entrypoint).
* **A full-screen view**: A Flutter screen pushed on top of the native screen
  (`main` entrypoint).

Each one runs in its own Flutter engine.

## Layout

```
native-hybrid-app/
├── flutter_module/   # The Flutter content, shared by both host apps
├── ios/              # Native iOS host app (UIKit, CocoaPods)
└── android/          # Native Android host app (Kotlin, Gradle)
```

## Setup

Generate the credential files from the repository root. This writes
`android/app/src/main/res/raw/dd_config.json` and
`ios/HybridSessionReplayExample/ddog_config.plist`, which are ignored by Git:

```bash
DD_CLIENT_TOKEN=<client token> DD_APPLICATION_ID=<application id> ./generate_env.sh
```

Do not commit real client tokens or application IDs. Without credentials, the
native SDK doesn't initialize, Flutter can't attach to it, and the Flutter
views show this error:

```
Null check operator used on a null value
```

The Flutter logs also show:

```
[Datadog 🐶🔥 ] Failed to attach to an existing native instance of the Datadog SDK.
```

Then fetch the Flutter module's dependencies. This also generates the
`.ios` and `.android` folders that the host apps build against:

```bash
cd flutter_module
flutter pub get
```

### iOS

```bash
cd ios
pod install
open HybridSessionReplayExample.xcworkspace
```

Run the `HybridSessionReplayExample` scheme. Hybrid Session Replay needs
dd-sdk-ios 3.16.0 or later.

### Android

Open the `android` folder in Android Studio and run the `app` configuration,
or build from the command line:

```bash
cd android
./gradlew installDebug
```

Hybrid Session Replay needs dd-sdk-android 3.13.0 or later. The example uses
3.13.1, the version that `datadog_flutter_plugin` pins.

## How it works

### Native side

The native app initializes Datadog, RUM, and Session Replay before any Flutter
engine runs (`AppDelegate.swift`, `HybridApplication.kt`). Then it opts each
Flutter view in to Session Replay:

```swift
// iOS
let flutterViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
flutterViewController.dd.enableSessionReplay()
```

```kotlin
// Android
flutterFragment.enableSessionReplay()   // FlutterFragment
enableSessionReplay()                   // inside a FlutterActivity
```

### Flutter side

Each engine attaches to the native SDK with `attachToExisting` and enables
Session Replay with `isEmbedded: true` (`flutter_module/lib/main.dart`).
Records are then handed to the native Session Replay instead of being
uploaded from Flutter. As in any Flutter app, a `SessionReplayCapture` widget
sits above `MaterialApp`.

### Sampling and privacy

The native `replaySampleRate` decides which sessions get a replay. When
`isEmbedded` is `true`, the Flutter `replaySampleRate` is ignored.

Privacy levels are not shared between the native and Flutter SDKs, so this
example sets the same ones on both sides:

* **Text and input privacy**: `maskSensitiveInputs`
* **Image privacy**: `maskNone`
* **Touch privacy**: `show`

The password field on the full-screen Flutter view is masked in the replay.

### RUM views

Both host apps use the default RUM view tracking, so each Flutter view
controller or activity is its own RUM view. The full-screen Flutter view gets
its own view in the replay, and the embedded panel is part of the native
screen's view.
