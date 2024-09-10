// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/named_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  void _goToPage(String page) {
    context.go(page);
  }

  Widget _paddedNavButton(String text, String page) {
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
        appBar: AppBar(
          title: const Text('Example App'),
        ),
        body: Center(
          child: Column(
            children: [
              _paddedNavButton('Home', '/home'),
              _paddedNavButton('Network', '/network'),
              _paddedNavButton('GraphQl', '/graphql'),
              _paddedNavButton('Crash', '/crash'),
            ],
          ),
        ));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  DatadogLogger? _logger;

  @override
  void initState() {
    _logger =
        DatadogSdk.instance.logs?.createLogger(DatadogLoggerConfiguration());
    super.initState();
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  void _goToNamedScreen() {
    _logger?.info('Some info');
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Named Screen'),
        builder: (context) => const NamedScreen(),
      ),
    );
  }

  void _openDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Container(
          height: 100,
          width: 120,
          color: Colors.white,
          child: Column(
            children: [
              TextButton(
                child: const Text('CLOSE MODAL'),
                onPressed: () => {
                  debugPrint('MODAL REJECTED'),
                  context.pop(),
                },
              ),
              TextButton(
                onPressed: () => {
                  context.pop(),
                },
                child: const Text('ACCEPT MODAL'),
              ),
              IconButton(
                key: const Key('REJECT BY ICON'),
                icon: const Icon(Icons.close),
                onPressed: () async => {
                  await Future.delayed(const Duration(seconds: 5), () {
                    context.pop();
                  }),
                },
              ),
              IconButton(
                key: const Key('ACCEPT BY ICON KEY'),
                icon: const Icon(Icons.done),
                tooltip: 'MODAL ACCEPT BY ICON',
                onPressed: () => {
                  context.pop(),
                },
              )
            ],
          ),
        );
      },
      routeSettings: RouteSettings(name: 'Download Dialog'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            ElevatedButton(
              onPressed: _goToNamedScreen,
              child: const Text('Named Test'),
            ),
            ElevatedButton(
              onPressed: () => _openDialog(context),
              child: const Text('Open Dialog'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
