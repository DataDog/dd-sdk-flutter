// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../scenario_config.dart';
import 'rum_http_instrumentation_third_screen.dart';

class RumHttpInstrumentationSecondScreen extends StatefulWidget {
  final http.Client client;

  const RumHttpInstrumentationSecondScreen({Key? key, required this.client})
      : super(key: key);

  @override
  State<RumHttpInstrumentationSecondScreen> createState() =>
      _RumHttpInstrumentationSecondScreenState();
}

class _RumHttpInstrumentationSecondScreenState
    extends State<RumHttpInstrumentationSecondScreen> {
  late Future _loadingFuture;
  late RumAutoInstrumentationScenarioConfig _config;
  var _currentStatus = 'Starting fetch';

  @override
  void initState() {
    super.initState();
    _config = RumAutoInstrumentationScenarioConfig.instance;
    _loadingFuture = _fetchResources();
  }

  Future<void> _fetchResources() async {
    // First Party Hosts
    await widget.client.get(Uri.parse(_config.firstPartyGetUrl));
    if (_config.firstPartyPostUrl != null) {
      setState(() {
        _currentStatus = 'Post First Party';
      });
      await widget.client.post(Uri.parse(_config.firstPartyPostUrl!));
    }

    setState(() {
      _currentStatus = 'Get First Party - Bad Request';
    });
    try {
      await widget.client.get(Uri.parse(_config.firstPartyBadUrl));
    } catch (e) {
      // ignore: avoid_print
      print('Request failed: $e');
    }

    setState(() {
      _currentStatus = 'Third party get';
    });
    await widget.client.get(Uri.parse(_config.thirdPartyGetUrl));

    setState(() {
      _currentStatus = 'Third party post';
    });
    await widget.client.post(Uri.parse(_config.thirdPartyPostUrl));
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
        settings: const RouteSettings(name: 'rum_http_third_screen'),
        builder: (_) => const RumHttpInstrumentationThirdScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secondary Screen'),
      ),
      body: FutureBuilder(
        future: _loadingFuture,
        builder: (context, snapshot) {
          return snapshot.connectionState == ConnectionState.done
              ? _buildLoaded()
              : Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      Text(_currentStatus),
                    ],
                  ),
                );
        },
      ),
    );
  }
}
