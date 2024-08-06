// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'main_screen.dart';
import 'screens/crash_screen.dart';
import 'screens/graph_ql_screen.dart';
import 'screens/network_screen.dart';

class MyApp extends StatelessWidget {
  final GraphQLClient graphQLClient;

  MyApp({Key? key, required this.graphQLClient}) : super(key: key);

  final router = GoRouter(
    observers: [DatadogNavigationObserver(datadogSdk: DatadogSdk.instance)],
    routes: [
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
    ],
  );

  @override
  Widget build(BuildContext context) {
    return GraphQLProvider(
      client: ValueNotifier<GraphQLClient>(graphQLClient),
      child: RumUserActionDetector(
        rum: DatadogSdk.instance.rum,
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
