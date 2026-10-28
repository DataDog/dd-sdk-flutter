// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  DatadogSdk.instance.sdkVerbosity = CoreLoggerLevel.debug;

  final configuration =
      DatadogConfiguration(
        clientToken: dotenv.get('DD_CLIENT_TOKEN', fallback: ''),
        env: dotenv.get('DD_ENV', fallback: ''),
        site: DatadogSite.us1,
        service: 'com.datadoghq.webview-session-replay-example',
        rumConfiguration: DatadogRumConfiguration(
          applicationId: dotenv.get('DD_APPLICATION_ID', fallback: ''),
          sessionSamplingRate: 100,
        ),
      )..enableSessionReplay(
        DatadogSessionReplayConfiguration(
          replaySampleRate: 100,
          startRecordingImmediately: true,
          // These are shared with the WebView too: the Browser SDK masks web
          // content with the matching web privacy level (here, `allow`).
          textAndInputPrivacyLevel:
              TextAndInputPrivacyLevel.maskSensitiveInputs,
          imagePrivacyLevel: ImagePrivacyLevel.maskNone,
          touchPrivacyLevel: TouchPrivacyLevel.show,
        ),
      );

  // Session Replay must be enabled before any WebView is tracked: whether the
  // Browser SDK sends its replay records is decided when `trackDatadogEvents`
  // runs.
  await DatadogSdk.runApp(configuration, TrackingConsent.granted, () async {
    runApp(const ExampleApp());
  });
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final _captureKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // SessionReplayCapture must sit above MaterialApp so it sees the whole
    // widget tree, including the WebView's platform view.
    return SessionReplayCapture(
      key: _captureKey,
      rum: DatadogSdk.instance.rum!,
      sessionReplay: DatadogSessionReplay.instance!,
      child: MaterialApp(
        title: 'WebView Session Replay Example',
        theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
        navigatorObservers: [
          DatadogNavigationObserver(datadogSdk: DatadogSdk.instance),
        ],
        home: const HomeScreen(),
      ),
    );
  }
}
