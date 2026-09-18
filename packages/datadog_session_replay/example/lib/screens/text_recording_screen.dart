// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/material.dart';

class TextRecordingScreen extends StatelessWidget {
  const TextRecordingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Text Rendering')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            spacing: 5,
            children: [
              Text('Simple text.'),
              Divider(),
              Text(
                'More complicated text that will likely expand onto multiple lines on most phones.',
                style: theme.textTheme.bodyLarge,
              ),
              Divider(),
              Text(
                'Complicated text that will be clipped because it is too long to fit on screen.',
                style: theme.textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Divider(),
              RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyLarge,
                  text: 'A simple span with ',
                  children: [
                    TextSpan(
                      text: 'formatted ',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: 'text ',
                      style: theme.textTheme.bodyLarge?.copyWith(fontSize: 25),
                    ),
                    TextSpan(text: 'in the middle.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
