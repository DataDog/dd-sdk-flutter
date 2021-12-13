// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'logging_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(mergeWith: Platform.environment);

  final configuration = DdSdkConfiguration(
    clientToken: dotenv.env['DD_CLIENT_TOKEN'] ?? '',
    env: dotenv.env['DD_ENV'] ?? '',
    applicationId: dotenv.env['DD_APPLICATION_ID'] ?? '',
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
