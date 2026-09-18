// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';

class TouchPrivacyScreen extends StatefulWidget {
  const TouchPrivacyScreen({super.key});

  @override
  State<TouchPrivacyScreen> createState() => _TouchPrivacyScreenState();
}

class _TouchPrivacyScreenState extends State<TouchPrivacyScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Touch Privacy')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Text('Here touch recording should work'),
            SizedBox(height: 20.0),
            Text('The below pin pad should not show touches'),
            _pinPad(),
          ],
        ),
      ),
    );
  }

  Widget _pinPad() {
    return SessionReplayPrivacy(
      touchPrivacyLevel: TouchPrivacyLevel.hide,
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          spacing: 20.0,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PinButton(text: '1'),
                _PinButton(text: '2'),
                _PinButton(text: '3'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PinButton(text: '4'),
                _PinButton(text: '5'),
                _PinButton(text: '6'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PinButton(text: '7'),
                _PinButton(text: '8'),
                _PinButton(text: '9'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class _PinButton extends StatelessWidget {
  final String text;

  const _PinButton({required this.text}) : super();

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      color: Colors.lightBlueAccent,
      onPressed: () {},
      padding: EdgeInsets.all(20.0),
      shape: CircleBorder(),
      child: Text(text),
    );
  }
}
