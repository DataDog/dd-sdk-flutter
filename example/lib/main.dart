import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter/services.dart';

import 'logging_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final ddConfig = await rootBundle.loadStructuredData<Map<String, dynamic>>(
      'config/ddconfig.json', (value) => Future.value(jsonDecode(value)));

  final configuration = DdSdkConfiguration(
    clientToken: ddConfig['client_token'],
    env: ddConfig['env'],
    applicationId: ddConfig['applicationId'],
    trackingConsent: 'granted',
  );
  final ddsdk = DatadogSdk();
  ddsdk.initialize(configuration);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final items = ["Logging"];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Datadog SDK Example App'),
        ),
        body: Center(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              return ListTile(
                title: Text(items[i]),
                trailing: const Icon(Icons.arrow_right_sharp),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (buildContext) => const LoggingScreen()),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
