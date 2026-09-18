// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';
import 'screens/cupertino_widgets_screen.dart';
import 'screens/images_screen.dart';
import 'screens/main_screen.dart';
import 'screens/material_widgets_screen.dart';
import 'screens/simple_containers_screen.dart';
import 'screens/slivers_screen.dart';
import 'screens/text_fields_screen.dart';
import 'screens/text_recording_screen.dart';
import 'screens/touch_privacy_screen.dart';

const Color datadogPurple = Color.fromARGB(255, 99, 44, 166);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var captureKey = GlobalKey();
  GoRouter? router;

  _MyAppState() {
    router = GoRouter(
      observers: [DatadogNavigationObserver(datadogSdk: DatadogSdk.instance)],
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => MainScreen(onRecreateKey: _recreateKey),
        ),
        GoRoute(
          path: Routes.simpleContainers,
          builder: (context, state) => const SimpleContainersScreen(),
        ),
        GoRoute(
          path: Routes.textRecording,
          builder: (context, state) => TextRecordingScreen(),
        ),
        GoRoute(
          path: Routes.cupertinoWidgets,
          builder: (context, state) => CupertinoWidgetsScreen(),
        ),
        GoRoute(
          path: Routes.materialWidgets,
          builder: (context, state) => MaterialWidgetsScreen(),
        ),
        GoRoute(
          path: Routes.textFieldWidgets,
          builder: (context, state) => TextFieldsScreen(),
        ),
        GoRoute(
          path: Routes.slivers,
          builder: (context, state) => SliversScreen(),
        ),
        GoRoute(
          path: Routes.imageWidgets,
          builder: (context, state) => ImagesScreen(),
        ),
        GoRoute(
          path: Routes.touchPrivacy,
          builder: (context, state) => TouchPrivacyScreen(),
        ),
      ],
    );
  }

  void _recreateKey() {
    setState(() {
      captureKey = GlobalKey();
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SessionReplayCapture(
      key: captureKey,
      rum: DatadogSdk.instance.rum!,
      sessionReplay: DatadogSessionReplay.instance!,
      child: MaterialApp.router(color: datadogPurple, routerConfig: router),
    );
  }
}
