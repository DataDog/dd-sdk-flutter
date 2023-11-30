// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';

import '../widgets/custom_card.dart';

class MainScreen extends StatelessWidget {
  static const images = [
    'https://placekitten.com/300/300?image=1',
    'https://placekitten.com/300/300?image=2',
    'https://placekitten.com/300/300?image=3',
    'https://imgix.datadoghq.com/img/about/presskit/kit/press_kit.png'
  ];

  const MainScreen({super.key});

  void _onCapture() {
    DatadogSessionReplay.instance?.performCapture();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FlutterLogo(
              size: 100,
            ),
            Center(
              child: ElevatedButton(
                onPressed: _onCapture,
                child: const Text('Capture'),
              ),
            ),
            for (int i = 0; i < images.length; ++i)
              CustomCard(
                image: images[i],
                text: 'Item $i',
                onTap: null,
              ),
          ],
        ),
      ),
    );
  }
}
