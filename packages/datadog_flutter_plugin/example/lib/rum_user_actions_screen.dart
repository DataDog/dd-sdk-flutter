// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';

/// This screen is used to demonstrate / test the types of User actions
/// we can detect with the [RumUserActionDetector]. The detector is already
/// at the root of the application.
class RumUserActionsScreen extends StatefulWidget {
  const RumUserActionsScreen({Key? key}) : super(key: key);

  @override
  State<RumUserActionsScreen> createState() => _RumUserActionsScreenState();
}

class _RumUserActionsScreenState extends State<RumUserActionsScreen>
    with RouteAware, DatadogRouteAwareMixin {
  final _dropDownValues = ['Item 1', 'Item 2', 'Item 3'];
  String? _dropDownValue = 'Item 1';
  bool _checkboxChecked = false;
  int _radioValue = 0;
  bool _switchValue = false;

  Widget _buttonsSection() {
    return Wrap(
      children: [
        ElevatedButton(onPressed: () {}, child: const Text('Button A')),
        TextButton(onPressed: () {}, child: const Text('Button B')),
        OutlinedButton(onPressed: () {}, child: const Text('Button C')),
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
        )
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
              value: 0,
              groupValue: _radioValue,
              onChanged: _updateRadioValue,
            ),
            Radio<int>(
              value: 1,
              groupValue: _radioValue,
              onChanged: _updateRadioValue,
            ),
            Radio<int>(
              value: 2,
              groupValue: _radioValue,
              onChanged: _updateRadioValue,
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
