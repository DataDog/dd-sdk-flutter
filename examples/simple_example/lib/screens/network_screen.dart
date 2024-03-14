// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:flutter/material.dart';

import '../custom_card.dart';

class NetworkScreen extends StatelessWidget {
  static const images = [
    'https://picsum.photos/200',
    'https://imgix.datadoghq.com/img/about/presskit/kit/press_kit.png'
  ];

  const NetworkScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
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
