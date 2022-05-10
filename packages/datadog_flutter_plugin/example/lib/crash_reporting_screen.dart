// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:ffi';
import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final DynamicLibrary ffiLibrary = Platform.isAndroid
    ? DynamicLibrary.open('libffi_crash_test.so')
    : DynamicLibrary.process();

// ignore: non_constant_identifier_names
final void Function(int attribute) ffi_crash_test = ffiLibrary
    .lookup<NativeFunction<Void Function(Int32)>>('ffi_crash_test')
    .asFunction();

typedef NativeFfiCallback = Int32 Function(Int32);

final int Function(
        int attribute, Pointer<NativeFunction<NativeFfiCallback>> callback)
    // ignore: non_constant_identifier_names
    ffi_callback_test = ffiLibrary
        .lookup<
                NativeFunction<
                    Int32 Function(
                        Int32, Pointer<NativeFunction<NativeFfiCallback>>)>>(
            'ffi_callback_test')
        .asFunction();

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
    ffi_crash_test(value);
  }

  int ffiCallbackTest(
      int value, Pointer<NativeFunction<NativeFfiCallback>> callback) {
    return ffi_callback_test(value, callback);
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
  const CrashReportingScreen({Key? key}) : super(key: key);

  @override
  _CrashReportingScreenState createState() => _CrashReportingScreenState();
}

class _CrashReportingScreenState extends State<CrashReportingScreen> {
  final nativeCrashPlugin = NativeCrashPlugin();
  var _viewName = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Crash Reporting')),
      body: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Crash after starting RUM Session',
                style: theme.textTheme.headline6),
            Container(
              padding: const EdgeInsets.all(4),
              child: TextField(
                onChanged: (value) => _viewName = value,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), labelText: 'RUM view name'),
              ),
            ),
            Wrap(
              children: [
                for (final t in CrashType.values)
                  Container(
                    padding: const EdgeInsets.only(left: 5),
                    child: ElevatedButton(
                      onPressed: () => _crashAfterRumSession(t),
                      child: Text(t.description),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Crash before starting RUM Session',
                style: theme.textTheme.headline6),
            Wrap(
              children: [
                for (final t in CrashType.values)
                  Container(
                    padding: const EdgeInsets.only(left: 5),
                    child: ElevatedButton(
                      onPressed: () => _crashBeforeRumSession(t),
                      child: Text(t.description),
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _crashAfterRumSession(CrashType crashType) async {
    final viewName = _viewName.isEmpty ? 'Rum Crash View' : _viewName;
    DatadogSdk.instance.rum?.startView(viewName, viewName);
    await Future.delayed(const Duration(milliseconds: 100));

    _crash(crashType);
  }

  Future<void> _crashBeforeRumSession(CrashType crashType) async {
    await Future.delayed(const Duration(milliseconds: 100));

    // ignore: avoid_print
    _crash(crashType).onError((error, stackTrace) => print(error));
  }

  static int nativeCallback(int value) {
    throw Exception(('FFI Callback Exception with value $value'));
  }

  Future<void> _crash(CrashType crashType) async {
    switch (crashType) {
      case CrashType.flutterException:
        throw Exception('Testing crashes in flutter!');
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
        var value = nativeCrashPlugin.ffiCallbackTest(
            32, Pointer.fromFunction(nativeCallback, 8));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Native callback threw, returned default value of $value'),
          ),
        );
        break;
    }
  }
}
