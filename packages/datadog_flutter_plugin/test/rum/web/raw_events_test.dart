// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.
// ignore: library_annotations
@TestOn('browser')

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:datadog_flutter_plugin/src/rum/web/raw_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes WebAssembly module debug metadata', () {
    final module = RumWebWasmModule(
      url: 'https://example.com/main.dart.wasm',
      build_id: '',
      debug_info_type: 'sourcemap',
    );

    expect(
      (module.getProperty('url'.toJS) as JSString).toDart,
      'https://example.com/main.dart.wasm',
    );
    expect((module.getProperty('build_id'.toJS) as JSString).toDart, '');
    expect(
      (module.getProperty('debug_info_type'.toJS) as JSString).toDart,
      'sourcemap',
    );
  });
}
