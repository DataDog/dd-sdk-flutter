// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'rum_auto_instrumentation_third_screen.dart';
import 'scenario_config.dart';

class RumAutoInstrumentationSecondScreen extends StatefulWidget {
  const RumAutoInstrumentationSecondScreen({Key? key}) : super(key: key);

  @override
  State<RumAutoInstrumentationSecondScreen> createState() =>
      _RumAutoInstrumentationSecondScreenState();
}

class _RumAutoInstrumentationSecondScreenState
    extends State<RumAutoInstrumentationSecondScreen> {
  late Future _loadingFuture;
  late RumAutoInstrumentationScenarioConfig _config;
  var currentStatus = 'Starting fetch';

  @override
  void initState() {
    super.initState();
    _config = RumAutoInstrumentationScenarioConfig.instance;
    _loadingFuture = _fetchResources();
  }

  Future<void> _fetchResources() async {
    // First Party Hosts
    await http.get(Uri.parse(_config.firstPartyGetUrl));
    if (_config.firstPartyPostUrl != null) {
      setState(() {
        currentStatus = 'Post First Party';
      });
      await http.post(Uri.parse(_config.firstPartyPostUrl!));
    }

    setState(() {
      currentStatus = 'Get First Party - Bad Request';
    });
    try {
      await http.get(Uri.parse(_config.firstPartyBadUrl));
    } catch (e) {
      // ignore: avoid_print
      print('Request failed: $e');
    }

    setState(() {
      currentStatus = 'Third party get';
    });
    await http.get(Uri.parse(_config.thirdPartyGetUrl));

    setState(() {
      currentStatus = 'Third party post';
    });
    await http.post(Uri.parse(_config.thirdPartyPostUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secondary Screen'),
      ),
      body: FutureBuilder<void>(
        future: _loadingFuture,
        builder: (context, snapshot) {
          return snapshot.connectionState == ConnectionState.done
              ? _buildLoaded()
              : Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      Text(currentStatus),
                    ],
                  ),
                );
        },
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
    Navigator.of(context).push<void>(
      MaterialPageRoute(
          builder: (_) => const RumAutoInstrumentationThirdScreen()),
    );
  }
}
