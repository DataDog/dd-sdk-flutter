# Datadog Flutter Plugin - Additional Examples

This folder contains examples of using the Datadog Flutter Plugin in more complicated scenarios than what is covered in the [bundled example](../../packages/datadog_flutter_plugin/example/). It also serves as a test bed for those more complicated setups.

This includes:

* [Simple Example](./simple_example) - Includes examples of GoRouter integration, distributed tracing, interaction tracking, error/crash reporting, and Datadog Flags.
* [Session Replay Example](./session_replay_example) - Includes examples of Session Replay sampling with `replaySampleRate` and recording only selected screens with `startRecordingImmediately: false` and `startRecording` / `stopRecording`.
* [Hybrid Session Replay Example](./native-hybrid-app) - Includes native iOS and Android apps that embed Flutter content, recorded in the native app's Session Replay with `isEmbedded: true` and `enableSessionReplay()`.


If you have other scenarios that are not covered in this list, please reach out to Datadog.
