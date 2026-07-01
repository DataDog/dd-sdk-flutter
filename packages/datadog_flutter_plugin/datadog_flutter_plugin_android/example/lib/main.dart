// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

// This example app exists solely to provide an Android project for jnigen
// (see jnigen.yaml: android_example). It is required for resolving the Android
// SDK when regenerating JNI bindings and is not intended for use otherwise.

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('datadog_flutter_plugin_android example'),
        ),
      ),
    );
  }
}
