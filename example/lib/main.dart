import 'package:flutter/material.dart';

import 'package:datadog_sdk/datadog_sdk.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final configuration =
      DdSdkConfiguration(clientToken: "", env: "", applicationId: "");
  final ddsdk = DatadogSdk(configuration);
  ddsdk.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: const Center(
          child: Text('Hello World'),
        ),
      ),
    );
  }
}
