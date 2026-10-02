// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';

// VM-only capture-release proof. Request a full collection through the VM
// service rather than relying on allocation pressure or timing.
Future<void> collectGarbage() async {
  var info = await developer.Service.getInfo();
  info = info.serverUri == null
      ? await developer.Service.controlWebServer(
          enable: true, silenceOutput: true)
      : info;
  final uri = info.serverUri!;
  final socket = await WebSocket.connect(
      uri.replace(scheme: 'ws', path: '${uri.path}ws').toString());
  final responses = StreamIterator<dynamic>(socket);
  try {
    socket.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': 'gc',
      'method': 'getAllocationProfile',
      'params': {
        'isolateId': developer.Service.getIsolateId(Isolate.current),
        'gc': true
      }
    }));
    while (await responses.moveNext()) {
      final response =
          jsonDecode(responses.current as String) as Map<String, dynamic>;
      if (response['id'] != 'gc') continue;
      if (response.containsKey('error')) {
        throw StateError('${response['error']}');
      }
      return;
    }
    throw StateError('VM service closed before GC response');
  } finally {
    await responses.cancel();
    await socket.close();
  }
}

class Capture {
  int calls = 0;
  void use() {
    calls++;
  }
}

@pragma('vm:never-inline')
bool hasTarget(WeakReference<Capture> reference) => reference.target != null;
