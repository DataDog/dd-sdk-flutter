// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2024-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'inappbrowser_example.dart';
import 'webview_example.dart';

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final router = GoRouter(
    observers: [DatadogNavigationObserver(datadogSdk: DatadogSdk.instance)],
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          return const Home();
        },
      ),
      GoRoute(
        path: '/webview',
        builder: (context, state) {
          return const WebviewExample();
        },
      ),
      GoRoute(
        path: '/browser',
        builder: (context, state) {
          return const InAppBrowserExample();
        },
      )
    ],
  );

  @override
  Widget build(BuildContext context) {
    return RumUserActionDetector(
      rum: DatadogSdk.instance.rum,
      child: MaterialApp.router(
        title: 'InAppWebview Examples',
        theme: ThemeData.from(
            colorScheme:
                ColorScheme.fromSwatch(primarySwatch: Colors.deepPurple)),
        routerConfig: router,
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  void _goToPage(String page) {
    context.push(page);
  }

  Widget _paddedNavItem(String text, String page) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        child: Text(text),
        onPressed: () => _goToPage(page),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('InAppWebview Example')),
      body: Center(
        child: Column(
          children: [
            _paddedNavItem('WebView Example', '/webview'),
            _paddedNavItem('InAppBrowser Example', '/browser'),
          ],
        ),
      ),
    );
  }
}
