// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

// Ignore the fact that we're not using RadioGroup as that is Flutter 3.35 exclusive
// ignore_for_file: deprecated_member_use

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';

/// This screen is used to demonstrate / test the types of User actions
/// we can detect with the [RumUserActionDetector]. The detector is already
/// at the root of the application.
class RumUserActionsScreen extends StatefulWidget {
  const RumUserActionsScreen({super.key});

  @override
  State<RumUserActionsScreen> createState() => _RumUserActionsScreenState();
}

class _RumUserActionsScreenState extends State<RumUserActionsScreen> {
  final _dropDownValues = ['Item 1', 'Item 2', 'Item 3'];
  String? _dropDownValue = 'Item 1';
  bool _checkboxChecked = false;
  int _radioValue = 0;
  bool _switchValue = false;

  @override
  void initState() {
    super.initState();

    DatadogSdk.instance.rum?.startView('RumUserActionScreen');
  }

  void _buttonPressed(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tapped $name')),
    );
  }

  Widget _buttonsSection() {
    return Wrap(
      children: [
        ElevatedButton(
          onPressed: () => _buttonPressed('Button A'),
          child: const Text('Button A'),
        ),
        TextButton(
          onPressed: () => _buttonPressed('Button B'),
          child: const Text('Button B'),
        ),
        OutlinedButton(
          onPressed: () => _buttonPressed('Button C'),
          child: const Text('Button C'),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.auto_awesome,
            semanticLabel: 'Button E',
          ),
        ),
        DropdownButton<String>(
          value: _dropDownValue,
          items: _dropDownValues
              .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _dropDownValue = value;
            });
          },
        ),
        // When wrapping a tappable widget with the RumUserActionAnnotation, the description
        // and attributes will be sent to Datadog when the user interacts with the inner widget
        // (ElevatedButton in this case).
        //
        // Here Datadog will receive a user action with the description 'ElevatedButton(Alternative Button A)'
        // and the attribute 'custom_attribute'.
        RumUserActionAnnotation(
          description: 'Alternative Button A',
          attributes: const {'custom_attribute': 'can be added too'},
          child: ElevatedButton(
            onPressed: () => _buttonPressed('Button A'),
            child: const Text('Button A'),
          ),
        ),
        // You can also create a custom button widget that wraps the inner widget with
        // a RumUserActionAnnotation. This way you can reuse the custom button in multiple
        // places in your app and still benefits for correct reports in Datadog.
        //
        // Note: to get "CustomButton" type in the Datadog action, you need to set this type
        // as a custom gesture detector in RumUserActionDetector (see example below).
        //
        // Here Datadog will receive a user action with the description 'CustomButton(Custom Button A)'
        // and the attribute 'custom_attribute'.
        CustomButton(
          debugActionLabel: 'Custom Button A',
          attributes: const {'custom_attribute': 'can be added too'},
          text: 'Button A',
          onPressed: () => _buttonPressed('Button A'),
        ),
      ],
    );
  }

  void _updateRadioValue(int? value) {
    setState(() {
      _radioValue = value ?? 0;
    });
  }

  Widget _formSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _checkboxChecked,
          onChanged: ((value) {
            setState(() {
              _checkboxChecked = value == true;
            });
          }),
        ),
        Row(
          children: [
            Radio<int>(
              groupValue: _radioValue,
              onChanged: _updateRadioValue,
              value: 0,
            ),
            Radio<int>(
              groupValue: _radioValue,
              onChanged: _updateRadioValue,
              value: 1,
            ),
            Radio<int>(
              groupValue: _radioValue,
              onChanged: _updateRadioValue,
              value: 2,
            )
          ],
        ),
        Switch(
          value: _switchValue,
          onChanged: (value) => setState(() {
            _switchValue = value;
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RumUserActionDetector(
      rum: DatadogSdk.instance.rum,
      customGestureDetector: (widget) {
        if (widget is CustomButton) {
          return const RumGestureDetectorInfo('CustomButton');
        }
        return null;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('User Action Examples'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Buttons'),
              Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 10),
                  child: _buttonsSection()),
              const Text('Form Controls'),
              Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 10),
                child: _formSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomButton extends StatelessWidget {
  final String debugActionLabel;
  final Map<String, Object?>? attributes;
  final String? text;
  final VoidCallback? onPressed;

  const CustomButton({
    required this.debugActionLabel,
    this.attributes,
    this.text,
    this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return RumUserActionAnnotation(
      description: debugActionLabel,
      attributes: attributes,
      child: ElevatedButton(
        onPressed: onPressed,
        child: text != null ? Text(text!) : null,
      ),
    );
  }
}
