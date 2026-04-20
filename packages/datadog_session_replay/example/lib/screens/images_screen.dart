// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/material.dart';

class ImagesScreen extends StatefulWidget {
  const ImagesScreen({super.key});

  @override
  State<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends State<ImagesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Images')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  Icon(Icons.favorite, color: Colors.red, size: 32),
                  Icon(Icons.home, color: Colors.blue, size: 32),
                  Icon(Icons.settings, size: 32),
                ],
              ),
            ),
            Image.asset('assets/dd_logo_v_rgb.png'),
            Image.network(
              'https://imgix.datadoghq.com/img/about/presskit/kit/press_kit.png',
            ),
          ],
        ),
      ),
    );
  }
}
