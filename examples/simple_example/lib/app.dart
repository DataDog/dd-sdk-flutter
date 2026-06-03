// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'main_screen.dart';
import 'flags/flags_demo_runtime.dart';
import 'screens/flags_screen.dart';
import 'screens/crash_screen.dart';
import 'screens/graph_ql_screen.dart';
import 'screens/network_screen.dart';

class MyApp extends StatefulWidget {
  final GraphQLClient graphQLClient;
  final FlagsDemoRuntime flagsRuntime;

  const MyApp({
    super.key,
    required this.graphQLClient,
    required this.flagsRuntime,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var captureKey = GlobalKey();

  late final router = GoRouter(observers: [
    DatadogNavigationObserver(datadogSdk: DatadogSdk.instance)
  ], routes: [
    GoRoute(
      path: '/',
      builder: (context, state) {
        return const MainScreen();
      },
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) {
        return const MyHomePage(title: 'Home');
      },
    ),
    GoRoute(
      path: '/network',
      builder: (context, state) {
        return const NetworkScreen();
      },
    ),
    GoRoute(
      path: '/graphql',
      builder: (context, state) {
        return const GraphQlScreen();
      },
    ),
    GoRoute(
      path: '/crash',
      builder: (context, state) {
        return const CrashTestScreen();
      },
    ),
    GoRoute(
      path: '/flags',
      builder: (context, state) {
        return FlagsScreen(runtime: widget.flagsRuntime);
      },
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    return GraphQLProvider(
      client: ValueNotifier<GraphQLClient>(widget.graphQLClient),
      child: SessionReplayCapture(
        key: captureKey,
        rum: DatadogSdk.instance.rum!,
        sessionReplay: DatadogSessionReplay.instance!,
        child: MaterialApp.router(
          title: 'Flutter Demo',
          theme: ThemeData.from(
            colorScheme:
                ColorScheme.fromSwatch(primarySwatch: Colors.deepPurple),
          ),
          routerConfig: router,
        ),
      ),
    );
  }
}
