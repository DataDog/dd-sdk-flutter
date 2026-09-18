// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.
import 'package:flutter/material.dart';

class UnnamedScreen extends StatelessWidget {
  const UnnamedScreen({super.key});

  void _onPressed() {
    throw Exception('I had an exception. :(');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unnamed Screen')),
      body: Center(
        child: ElevatedButton(
          onPressed: _onPressed,
          child: const Text('Throw Error'),
        ),
      ),
    );
  }
}
