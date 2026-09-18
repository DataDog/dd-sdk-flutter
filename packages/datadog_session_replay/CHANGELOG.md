# Changelog

## 1.0.0-preview.13

* Guard against non-finite (NaN/Infinity) values during recording.
* Render Switch Thumb Icon and use Material Icons for Checkbox glyphs.
* Render Material and Cupertino buttons correctly.
* Add support for Material and Cupertino Slider
* Add image downscaling with a configurable pixel budget.
* Add a configurable font-family transform.
* Add `captureGestures` option to `stopRecording`.
* Add `startRecording` and `stopRecording` support.

## 1.0.0-preview.12

* Add support for `Switch` and `CupertinoSwitch`.
* Recognize `ExactAssetImage` as an asset when masking non-assets.
* Include RUM context when writing Session Replay resources on Android.
* Shutdown the processing isolate on lifecycle detach.

## 1.0.0-preview.11

* Fix lifecycle issue with Android calling a dead callback on activity destruction.

## 1.0.0-preview.10

* Update required minimum version of `datadog_flutter_plugin` to 3.1.0 to support changes in iOS core libraries.

## 1.0.0-preview.9

* Switch to using a Singleton bridge for SessionReplay on Android to prevent crashes on Hot Restart. See [#932](https://github.com/DataDog/dd-sdk-flutter/issues/932)
* Add missing Proguard rules for Android. See [#932](https://github.com/DataDog/dd-sdk-flutter/issues/932)

## 1.0.0-preview.8

* Support getting context from background isolates.
* Prevent a deadlock when fetching context.
* Update Kotlin version to 2.1.0.
* Upgrade Android min versions for v3.
* Update plugin APIs to v3 to avoid compiler errors.

## 1.0.0-preview.7

* [Session Replay] Fix using `BoxShape.circle` in `BoxDecoration`.
* [Session Replay] Don't attempt to capture unmounted widgets.

## 1.0.0-preview.6

* [Session Replay] Don't capture elements with width or height of zero.

## 1.0.0-preview.5

* [Session Replay] Downgrade packages that required Dart versions above 3.6.

## 1.0.0-preview.4

* Fix an issue with custom endpoints on iOS.
* Drop session replay Dart requirement to 3.6.

## 1.0.0-preview.3

* Add classes to Proguard rules to prevent stripping. See [#851](https://github.com/DataDog/dd-sdk-flutter/issues/851).

## 1.0.0-preview.2

* Fix ignored generated files.

## 1.0.0-preview.1

* Initial release of Datadog Session Replay with the following features:
    * Capture containers, text, images, icons, and touches.
    * Support for masking sensitive data, including masking all user input or sensitive input fields.
    * Support for "fine grained" text, image, and touch masking with `SessionReplayPrivacy` widget.
* The following features are not supported in this preview:
    * Hybrid Session Replay
        * Native iOS and Android applications with Flutter views are not currently supported.
        * Flutter applications with native view are not currently supported.
        * Capture of Web Views is not currently supported.
    * Certain simple Material / Cupertino widgets are not captured.
    * Text from RichText widgets is captured, but only use the top most text style.
    * Flutter Web is not currently supported.
    * Manual recording is not currently supported.
