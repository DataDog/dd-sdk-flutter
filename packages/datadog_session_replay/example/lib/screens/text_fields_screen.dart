// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TextFieldsScreen extends StatefulWidget {
  const TextFieldsScreen({super.key});

  @override
  State<TextFieldsScreen> createState() => _TextFieldsScreenState();
}

class _TextFieldsScreenState extends State<TextFieldsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Text Fields')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          spacing: 12,
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Simple Text Field'),
            ),
            CupertinoTextField(placeholder: 'Cupertino Text Field'),
            TextField(
              decoration: InputDecoration(
                labelText: 'Bordered Text Field',
                border: OutlineInputBorder(),
              ),
            ),
            TextField(
              decoration: InputDecoration(
                labelText: 'Multiline Text Field',
                border: OutlineInputBorder(),
              ),
              minLines: 3,
              maxLines: 5,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Password Field'),
              obscureText: true,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Email Field'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Phone Field'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Address Field'),
              keyboardType: TextInputType.streetAddress,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Visible Password'),
              keyboardType: TextInputType.visiblePassword,
            ),
          ],
        ),
      ),
    );
  }
}
