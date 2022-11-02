import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

// A helper class to help with dismissing Flutter
class Dismisser {
  static Dismisser? _singleton;
  static Dismisser get instance {
    _singleton ??= Dismisser._();
    return _singleton!;
  }

  // Only used on iOS
  final _dismissChannel =
      const MethodChannel("com.datadoghq/dismissFlutterViewController");

  Dismisser._();

  Future<void> dismiss() async {
    if (Platform.isAndroid) {
      SystemNavigator.pop(animated: true);
    } else if (Platform.isIOS) {
      _dismissChannel.invokeMethod("dismiss");
    }
  }
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const MyHomePage(title: 'Flutter Demo Home Page'),
      ),
      GoRoute(
        path: '/page2',
        builder: (context, state) => const MySecondPage(),
      )
    ],
    observers: [
      DatadogNavigationObserver(datadogSdk: DatadogSdk.instance),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  bool _performingOperation = false;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  Future<void> _triggerResourceFetch() async {
    DatadogSdk.instance.rum
        ?.addUserAction(RumUserActionType.tap, 'Resource Fetch');

    setState(() {
      _performingOperation = true;
    });
    final _ = await http.get(Uri.parse('https://httpstat.us/200?sleep=500'));

    setState(() {
      _performingOperation = false;
    });
  }

  void _triggerLongTask() {
    DatadogSdk.instance.rum
        ?.addUserAction(RumUserActionType.tap, 'Long Task Button');
    final delayEnd = DateTime.now().add(const Duration(milliseconds: 300));
    while (DateTime.now().isBefore(delayEnd)) {}
  }

  void _pushSecondPage() {
    GoRouter.of(context).push('/page2');
  }

  void _onClose() {
    Dismisser.instance.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: _onClose,
            icon: const Icon(Icons.close),
          )
        ],
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
              style: Theme.of(context).textTheme.headline4,
            ),
            ElevatedButton(
              onPressed: _performingOperation ? null : _triggerResourceFetch,
              child: const Text('Fetch Resource'),
            ),
            ElevatedButton(
              onPressed: _performingOperation ? null : _triggerLongTask,
              child: const Text('Trigger Long Task'),
            ),
            ElevatedButton(
              onPressed: _performingOperation ? null : _pushSecondPage,
              child: const Text('Push Second Page'),
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

class MySecondPage extends StatelessWidget {
  const MySecondPage({super.key});

  void _onClose() {
    Dismisser.instance.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Second Page'),
        actions: [
          IconButton(
            onPressed: _onClose,
            icon: const Icon(Icons.close),
          )
        ],
      ),
      body: const Center(child: Text('This is a second page')),
    );
  }
}
