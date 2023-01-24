// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';

import 'crash_reporting_screen.dart';
import 'logging_screen.dart';
import 'rum_screen.dart';

class NavItem {
  final String label;
  final String route;

  NavItem({required this.label, required this.route});
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({Key? key}) : super(key: key);

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final router = FluroRouter();

  final items = <NavItem>[
    NavItem(label: 'Logging', route: '/logging'),
    NavItem(label: 'RUM', route: '/rum'),
    NavItem(label: 'RUM Crash Reporting', route: '/rum_crash'),
  ];

  @override
  void initState() {
    super.initState();

    router.define('/logging',
        handler: Handler(handlerFunc: (_, __) => const LoggingScreen()));
    router.define('/rum',
        handler: Handler(handlerFunc: (_, __) => const RumScreen()));
    router.define('/rum_crash',
        handler: Handler(handlerFunc: (_, __) => const CrashReportingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateRoute: router.generator,
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Datadog SDK Example App'),
          ),
          body: Center(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                var item = items[i];
                return ListTile(
                  title: Text(item.label),
                  trailing: const Icon(Icons.arrow_right_sharp),
                  onTap: () {
                    router.navigateTo(context, item.route,
                        transition: TransitionType.native);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
