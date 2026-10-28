# Datadog Flutter Plugin - Additional Examples

This folder contains examples of using the Datadog Flutter Plugin in more complicated scenarios than what is covered in the [bundled example](../../packages/datadog_flutter_plugin/example/). It also serves as a test bed for those more complicated setups.

This includes:

* [Simple Example](./simple_example) - Includes examples of GoRouter integration, distributed tracing, interaction tracking, error/crash reporting, and Datadog Flags.
* [Session Replay Example](./session_replay_example) - Includes examples of Session Replay sampling with `replaySampleRate`, and manual recording control with `startRecordingImmediately: false`, `startRecording`, and `stopRecording`.
* [WebView Session Replay Example](./webview_session_replay_example) - Includes Session Replay recording a WebView that runs the Datadog Browser SDK, with `datadog_webview_tracking`, so the web content joins the app's replay (iOS).
* [Hybrid Session Replay Example](./native-hybrid-app) - Includes native iOS and Android apps that embed Flutter content, recorded in the native app's Session Replay with `isEmbedded: true` and `enableSessionReplay()`.


If you have other scenarios that are not covered in this list, please reach out to Datadog.
