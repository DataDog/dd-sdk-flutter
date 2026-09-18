// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../scenario_config.dart';
import 'instrumentation_third_screen.dart';

class InstrumentationSecondScreen extends StatefulWidget {
  final Dio dio;

  const InstrumentationSecondScreen({super.key, required this.dio});

  @override
  State<InstrumentationSecondScreen> createState() =>
      _InstrumentationSecondScreenState();
}

class _InstrumentationSecondScreenState
    extends State<InstrumentationSecondScreen> {
  bool _performingOperations = false;
  String _buttonText = 'Fetch Resources';
  bool _done = false;
  late RumAutoInstrumentationScenarioConfig _config;

  @override
  void initState() {
    super.initState();
    _config = RumAutoInstrumentationScenarioConfig.instance;
  }

  Future<void> _fetchResources() async {
    setState(() {
      _performingOperations = true;
    });

    // First Party Hosts
    await widget.dio.getUri(Uri.parse(_config.firstPartyGetUrl));
    if (_config.firstPartyPostUrl != null) {
      setState(() {
        _buttonText = 'Post First Party';
      });
      await widget.dio.postUri(Uri.parse(_config.firstPartyPostUrl!));
    }

    setState(() {
      _buttonText = 'Get First Party - Bad Request';
    });
    try {
      await widget.dio.getUri(Uri.parse(_config.firstPartyBadUrl));
    } catch (e) {
      // ignore: avoid_print
      print('Request failed: $e');
    }

    setState(() {
      _buttonText = 'Third party get';
    });
    await widget.dio.getUri(Uri.parse(_config.thirdPartyGetUrl));

    setState(() {
      _buttonText = 'Third party post';
    });
    await widget.dio.postUri(Uri.parse(_config.thirdPartyPostUrl));

    setState(() {
      _buttonText = 'Third party missing url';
    });
    try {
      await widget.dio.getUri(Uri.parse(_config.thirdPartyMissingUrl));
    } catch (_) {
      // Do nothing, this will throw from Dio
    }

    await Future.delayed(const Duration(milliseconds: 100));
    setState(() {
      _buttonText = 'All Done';
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secondary Screen'),
      ),
      body: Column(
        children: [
          ElevatedButton(
              onPressed: _performingOperations ? null : () => _fetchResources(),
              child: Text(
                _buttonText,
              )),
          if (_done) _buildLoaded(),
        ],
      ),
    );
  }

  Widget _buildLoaded() {
    return Center(
      child: Column(
        children: [
          const Text('All Done'),
          ElevatedButton(
            onPressed: _onNext,
            child: const Text('Next Page'),
          ),
        ],
      ),
    );
  }

  void _onNext() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'rum_io_third_screen'),
        builder: (_) => const InstrumentationThirdScreen(),
      ),
    );
  }
}
