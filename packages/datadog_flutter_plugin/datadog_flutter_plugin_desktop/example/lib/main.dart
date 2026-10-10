import 'package:flutter/material.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'This example app exists to pull in the datadog_flutter_plugin_desktop\n'
            'CMake build, which downloads dd-sdk-cpp via FetchContent.\n\n'
            'Run `flutter build windows` (or linux) here before running ffigen.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
