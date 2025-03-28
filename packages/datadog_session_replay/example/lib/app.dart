// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/input_screen.dart';
import 'screens/main_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final captureKey = GlobalKey();

  final router = GoRouter(
    observers: [DatadogNavigationObserver(datadogSdk: DatadogSdk.instance)],
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          return const MainScreen();
        },
        routes: [
          GoRoute(
            path: 'input',
            builder: (context, state) {
              return const InputScreen();
            },
          )
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return SessionReplayCapture(
      sessionReplay: DatadogSessionReplay.instance!,
      rum: DatadogSdk.instance.rum,
      key: captureKey,
      child: MaterialApp.router(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          appBarTheme: const AppBarTheme(
            color: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
        routerConfig: router,
      ),
    );
  }
}
