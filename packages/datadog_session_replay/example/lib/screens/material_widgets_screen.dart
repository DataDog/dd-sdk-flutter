// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/material.dart';

class MaterialWidgetsScreen extends StatefulWidget {
  const MaterialWidgetsScreen({super.key});

  @override
  State<MaterialWidgetsScreen> createState() => _MaterialWidgetsScreenState();
}

class _MaterialWidgetsScreenState extends State<MaterialWidgetsScreen> {
  bool _switchOn = false;
  bool _checkboxOn = false;
  double _sliderValue = 100;
  String _segmentValue = 'value_a';
  int _pageIndex = 0;
  String? _radioValue;

  void _onSwitchChanged(bool value) {
    setState(() {
      _switchOn = value;
    });
  }

  void _onCheckboxChanged(bool? value) {
    setState(() {
      _checkboxOn = value ?? false;
    });
  }

  void _onSliderChanged(double value) {
    setState(() {
      _sliderValue = value;
    });
  }

  void _onSegmentControlChanged(Set<String> values) {
    setState(() {
      if (values.isNotEmpty) {
        _segmentValue = values.first;
      }
    });
  }

  void _onRadioChanged(String? value) {
    setState(() {
      _radioValue = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Material Widgets')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.edit),
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (index) {
          setState(() {
            _pageIndex = index;
          });
        },
        indicatorColor: Colors.amber,
        selectedIndex: _pageIndex,
        destinations: [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
            icon: Badge(child: Icon(Icons.notifications_sharp)),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Badge(label: Text('2'), child: Icon(Icons.messenger_sharp)),
            label: 'Messages',
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
                builder: (_) =>
                    ElevatedButton(child: Text('Button'), onPressed: () {}),
              ),
              _WidgetDisplay(
                name: 'Switch',
                builder: (_) =>
                    Switch(value: _switchOn, onChanged: _onSwitchChanged),
              ),
              _WidgetDisplay(
                name: 'Checkbox',
                builder: (_) => Checkbox(
                  value: _checkboxOn,
                  onChanged: _onCheckboxChanged,
                ),
              ),
              _WidgetDisplay(
                name: 'Radio',
                builder: (_) => Column(
                  children: [
                    Row(children: [
                      Radio<String>(
                        value: 'a',
                        groupValue: _radioValue,
                        onChanged: _onRadioChanged,
                      ),
                      Text('A')
                    ]),
                    Row(children: [
                      Radio<String>(
                        value: 'b',
                        groupValue: _radioValue,
                        onChanged: _onRadioChanged,
                      ),
                      Text('B')
                    ]),
                  ],
                ),
              ),
              _WidgetDisplay(
                name: 'Slider',
                builder: (_) => Slider(
                  min: 0,
                  max: 100,
                  divisions: 100,
                  value: _sliderValue,
                  onChanged: _onSliderChanged,
                ),
              ),
              _WidgetDisplay(
                name: 'Segmened Button',
                builder: (_) {
                  return SegmentedButton(
                    segments: [
                      ButtonSegment<String>(value: 'value_a', label: Text('A')),
                      ButtonSegment<String>(value: 'value_b', label: Text('B')),
                      ButtonSegment<String>(value: 'value_c', label: Text('C')),
                    ],
                    selected: <String>{_segmentValue},
                    onSelectionChanged: _onSegmentControlChanged,
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
