import 'package:flutter/material.dart';

import 'test_select_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Datadog Stress Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TestSelectScreen(),
    );
  }
}
