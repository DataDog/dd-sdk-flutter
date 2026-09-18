// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ffi_crasher/ffi_crasher.dart';

typedef CrashPluginCallback = void Function(String callbackValue);

/// Helper class to crash in native code
class NativeCrashPlugin {
  final _methodChannel =
      const MethodChannel('datadog_sdk_flutter.example.crash');

  int nextCallbackId = 0;
  final Map<int, CrashPluginCallback> _callbacks = {};

  NativeCrashPlugin() {
    _methodChannel.setMethodCallHandler(_methodCallHandler);
  }

  Future<void> crashNative() {
    return _methodChannel.invokeMethod('crashNative');
  }

  Future<void> throwException() {
    return _methodChannel.invokeMethod('throwException');
  }

  Future<void> performCallback(CrashPluginCallback callback) {
    var callbackID = nextCallbackId;
    _callbacks[callbackID] = callback;
    nextCallbackId += 1;

    return _methodChannel.invokeMethod(
      'performCallback',
      {
        'callbackId': callbackID,
      },
    );
  }

  void crashNativeFfi(int value) {
    FfiCrasher().crash(value);
  }

  int ffiCallbackTest(int value, NativeCallback callback) {
    return FfiCrasher().crashCallback(value, callback);
  }

  Future<void> _methodCallHandler(MethodCall call) async {
    final args = call.arguments as Map;
    if (call.method == 'nativeCallback') {
      final callbackId = args['callbackId'] as int;
      final callbackValue = args['callbackValue'] as String;
      final callback = _callbacks[callbackId];
      callback?.call(callbackValue);
      _callbacks.remove(callbackId);
    }
  }
}

enum CrashType {
  flutterException,
  methodChannelCrash,
  methodChannelException,
  methodChannelCallbackException,
  ffiCrash,
  ffiCallbackException,
}

extension CrashTypeDescription on CrashType {
  String get description {
    switch (this) {
      case CrashType.flutterException:
        return 'Flutter Exception';
      case CrashType.methodChannelCrash:
        return 'Method Channel Crash';
      case CrashType.methodChannelException:
        return 'Method Channel Exception / NSError';
      case CrashType.methodChannelCallbackException:
        return 'Method Channel Callback Exception';
      case CrashType.ffiCrash:
        return 'FFI Crash';
      case CrashType.ffiCallbackException:
        return 'FFI Callback Exception';
    }
  }
}

class CrashReportingScreen extends StatefulWidget {
  const CrashReportingScreen({super.key});

  @override
  State<CrashReportingScreen> createState() => _CrashReportingScreenState();
}

class _CrashReportingScreenState extends State<CrashReportingScreen> {
  final nativeCrashPlugin = NativeCrashPlugin();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crash Reporting')),
      body: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () => _crashNonAsync(),
              child: const Text('Non async crash'),
            ),
            for (final t in CrashType.values)
              Container(
                padding: const EdgeInsets.only(left: 5),
                child: ElevatedButton(
                  onPressed: () => _crashAsync(t),
                  child: Text(t.description),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _crashNonAsync() {
    _flutterException();
  }

  Future<void> _crashAsync(CrashType crashType) async {
    await Future.delayed(const Duration(milliseconds: 100));

    _crash(crashType);
  }

  void _flutterException() {
    // Iterate a list to get a system symbol in the stack.
    var xes = ['a', 'b', 'c'].map((element) {
      if (element == 'a') {
        throw Exception("This wasn't supposed to happen!");
      }
      return 'x';
    }).toList();
    xes.length;
  }

  static int nativeCallback(int value) {
    throw Exception(('FFI Callback Exception with value $value'));
  }

  Future<void> _crash(CrashType crashType) async {
    switch (crashType) {
      case CrashType.flutterException:
        _flutterException();
        break;
      case CrashType.methodChannelCrash:
        await nativeCrashPlugin.crashNative();
        break;
      case CrashType.methodChannelException:
        await nativeCrashPlugin.throwException();
        break;
      case CrashType.methodChannelCallbackException:
        await nativeCrashPlugin.performCallback((callbackValue) {
          throw Exception(
              'Method Channel Callback Exception - with value $callbackValue');
        });
        break;
      case CrashType.ffiCrash:
        nativeCrashPlugin.crashNativeFfi(23);
        break;
      case CrashType.ffiCallbackException:
        if (!kIsWeb) {
          var value = nativeCrashPlugin.ffiCallbackTest(32, nativeCallback);
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Native callback threw, returned default value of $value'),
            ),
          );
        }
        break;
    }
  }
}
