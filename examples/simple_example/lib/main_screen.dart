// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:test_app/placeholder_screen.dart';
import 'package:test_app/screens/crash_screen.dart';
import 'package:test_app/screens/named_screen.dart';
import 'package:test_app/screens/network_screen.dart';

class MainScreen extends StatefulWidget {
  final String? tab;

  const MainScreen({Key? key, required this.tab}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final tabs = ['home', 'network', 'crash'];
  var _selectedTabIndex = 0;

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedTabIndex = tabs.indexWhere((e) => widget.tab == e);
    if (_selectedTabIndex < 0) _selectedTabIndex = 0;
  }

  Widget getSelectedPage(BuildContext context) {
    switch (widget.tab) {
      case 'home':
        return const MyHomePage(title: 'Home');
      case 'network':
        return const NetworkScreen();
      case 'crash':
        return const CrashTestScreen();
    }

    return PlaceholderScreen(screenName: widget.tab ?? 'Unknown');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: getSelectedPage(context),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: 'Network'),
          BottomNavigationBarItem(icon: Icon(Icons.air), label: 'Crash'),
        ],
        onTap: (index) {
          final path = tabs[index];
          context.go('/$path');
        },
      ),
    );
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
        settings: const RouteSettings(name: "Named Screen"),
        builder: (context) => const NamedScreen(),
      ),
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
            )
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
