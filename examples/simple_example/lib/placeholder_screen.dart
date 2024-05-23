// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  final String screenName;

  const PlaceholderScreen({Key? key, required this.screenName})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(screenName),
      ),
    );
  }
}
