import 'package:flutter/material.dart';

import 'package:datadog_sdk/datadog_sdk.dart';

import 'logging_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final configuration = DdSdkConfiguration(
    clientToken: "",
    env: "",
    applicationId: "",
    trackingConsent: 'granted',
  );
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
