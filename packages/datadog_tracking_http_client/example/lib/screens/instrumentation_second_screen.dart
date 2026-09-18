// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:flutter/material.dart';

import '../clients/abstract_client.dart';
import '../scenario_config.dart';
import 'instrumentation_third_screen.dart';

class InstrumentationSecondScreen extends StatefulWidget {
  final AbstractClient client;

  const InstrumentationSecondScreen({Key? key, required this.client})
      : super(key: key);

  @override
  State<InstrumentationSecondScreen> createState() =>
      _InstrumentationSecondScreenState();
}

class _InstrumentationSecondScreenState
    extends State<InstrumentationSecondScreen> {
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
    // This is only for the sake of integration tests. Without it, Flutter
    // switches routes and starts loading images prior to `pumpAndSettle`
    // allowing sending the view change to RUM.
    await Future.delayed(const Duration(milliseconds: 10));

    // First Party Hosts
    await widget.client.get(Uri.parse(_config.firstPartyGetUrl));
    if (_config.firstPartyPostUrl != null) {
      setState(() {
        currentStatus = 'Post First Party';
      });
      await widget.client.post(Uri.parse(_config.firstPartyPostUrl!));
    }

    setState(() {
      currentStatus = 'Get First Party - Bad Request';
    });
    try {
      await widget.client.get(Uri.parse(_config.firstPartyBadUrl));
    } catch (e) {
      // ignore: avoid_print
      print('Request failed: $e');
    }

    setState(() {
      currentStatus = 'Third party get';
    });
    await widget.client.get(Uri.parse(_config.thirdPartyGetUrl));

    setState(() {
      currentStatus = 'Third party post';
    });
    await widget.client.post(Uri.parse(_config.thirdPartyPostUrl));

    await Future.delayed(const Duration(milliseconds: 100));
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
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'rum_io_third_screen'),
        builder: (_) => const InstrumentationThirdScreen(),
      ),
    );
  }
}
