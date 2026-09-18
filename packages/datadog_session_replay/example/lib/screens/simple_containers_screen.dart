// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/material.dart';

class SimpleContainersScreen extends StatelessWidget {
  const SimpleContainersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simple Containers')),
      body: Center(
        child: Column(
          children: [
            Material(
              elevation: 8.0,
              color: Colors.amberAccent,
              surfaceTintColor: Colors.purple,
              child: SizedBox(
                width: 100,
                height: 200,
                child: Center(child: Text('In a Material')),
              ),
            ),
            const SizedBox(width: 0, height: 20),
            ElevatedButton(onPressed: () {}, child: Text('My Button')),
            Container(
              decoration: BoxDecoration(
                border: Border.all(width: 2),
                borderRadius: BorderRadius.circular(10.0),
                color: Colors.blueAccent,
              ),
              width: 200.0,
              height: 200.0,
              alignment: Alignment.center,
              child: Text('In a Container\n'),
            ),
            Container(
              width: 100.0,
              height: 100.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(width: 2),
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
