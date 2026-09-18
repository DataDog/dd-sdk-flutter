// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CupertinoWidgetsScreen extends StatefulWidget {
  const CupertinoWidgetsScreen({super.key});

  @override
  State<CupertinoWidgetsScreen> createState() => _CupertinoWidgetsScreenState();
}

class _CupertinoWidgetsScreenState extends State<CupertinoWidgetsScreen> {
  bool _switchOn = false;
  double _sliderValue = 100;
  String _segmentValue = 'value_a';
  int _currentTab = 0;

  void _onSwitchChanged(bool value) {
    setState(() {
      _switchOn = value;
    });
  }

  void _onSliderChanged(double value) {
    setState(() {
      _sliderValue = value;
    });
  }

  void _onSegmentControlChanged(String? value) {
    if (value != null) {
      _segmentValue = value;
    }
  }

  void _onTabChanged(int value) {
    setState(() {
      _currentTab = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(middle: Text('Cupertino Widgets')),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: _currentTab,
        onTap: _onTabChanged,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.star_fill),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.clock_solid),
            label: 'Recents',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_alt_circle_fill),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.circle_grid_3x3_fill),
            label: 'Keypad',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Column(
            children: [
              _WidgetDisplay(
                name: 'Button',
                builder: (_) => CupertinoButton.filled(
                  child: Text('Button'),
                  onPressed: () {},
                ),
              ),
              _WidgetDisplay(
                name: 'Switch',
                builder: (_) => CupertinoSwitch(
                  value: _switchOn,
                  onChanged: _onSwitchChanged,
                ),
              ),
              _WidgetDisplay(
                name: 'Slider',
                builder: (_) => CupertinoSlider(
                  min: 0,
                  max: 100,
                  divisions: 100,
                  value: _sliderValue,
                  onChanged: _onSliderChanged,
                ),
              ),
              _WidgetDisplay(
                name: 'Sliding Segment Control',
                builder: (_) {
                  return CupertinoSlidingSegmentedControl(
                    groupValue: _segmentValue,
                    children: {
                      'value_a': Text('Value A'),
                      'value_b': Text('Value B'),
                      'value_c': Text('Value C'),
                    },
                    onValueChanged: _onSegmentControlChanged,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@immutable
class _WidgetDisplay extends StatelessWidget {
  final String name;
  final WidgetBuilder builder;

  const _WidgetDisplay({required this.name, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Row(children: [Expanded(child: Text(name)), builder(context)]);
  }
}
