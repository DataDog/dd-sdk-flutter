// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes.dart';

@immutable
class _RouteScreen {
  final String title;
  final String route;

  const _RouteScreen(this.title, this.route);
}

class MainScreen extends StatefulWidget {
  final VoidCallback onRecreateKey;

  const MainScreen({super.key, required this.onRecreateKey});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final routes = [
    _RouteScreen('Simple Containers', Routes.simpleContainers),
    _RouteScreen('Text Rendering', Routes.textRecording),
    _RouteScreen('Cupertino Widgets', Routes.cupertinoWidgets),
    _RouteScreen('Material Widgets', Routes.materialWidgets),
    _RouteScreen('Text Fields', Routes.textFieldWidgets),
    _RouteScreen('Slivers', Routes.slivers),
    _RouteScreen('Images', Routes.imageWidgets),
    _RouteScreen('Touch Privacy', Routes.touchPrivacy),
  ];

  void _stopSession() {
    DatadogSdk.instance.rum?.stopSession();
  }

  Widget _routeButton(BuildContext context, _RouteScreen route) {
    final theme = Theme.of(context);
    return InkWell(
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: Text(route.title, style: theme.textTheme.headlineSmall),
            ),
            Icon(Icons.arrow_right_sharp),
          ],
        ),
      ),
      onTap: () {
        context.push(route.route);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session Replay Example')),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _stopSession,
              child: Text('Stop Session'),
            ),
            for (final route in routes) _routeButton(context, route),
            ElevatedButton(
              onPressed: widget.onRecreateKey,
              child: Text('Recreate Capture Widget'),
            ),
          ],
        ),
      ),
    );
  }
}
