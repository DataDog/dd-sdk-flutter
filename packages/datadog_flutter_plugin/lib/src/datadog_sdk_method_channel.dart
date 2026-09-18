// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../datadog_flutter_plugin.dart';
import 'android/android_plugin_stub.dart'
    if (dart.library.io) 'android/android_plugin_ffi.dart';
import 'datadog_sdk_platform_interface.dart';
import 'internal_logger.dart';
import 'ios/ios_platform_bridge_stub.dart'
    if (dart.library.io) 'ios/ios_platform_bridge.dart';

@immutable
class _IsolateAttachRequest {
  final SendPort sendPort;

  const _IsolateAttachRequest({required this.sendPort});
}

class DatadogCommunicationError extends Error {
  final Object unknownMessage;
  DatadogCommunicationError(this.unknownMessage);

  @override
  String toString() {
    return 'Unknown object sent in internal communicaiton: $unknownMessage';
  }
}

class DatadogSdkMethodChannel extends DatadogSdkPlatform {
  static const String globalCommunicationPortName =
      'datadog.global.isolate.port';

  @visibleForTesting
  final methodChannel = const MethodChannel('datadog_sdk_flutter');

  LogCallback? _logCallback;

  @override
  DatadogContext? getContext() {
    if (Platform.isIOS) {
      return IosPlatformBridge.getContext();
    } else if (Platform.isAndroid) {
      return AndroidDatadogFlutterPlugin.getContext();
    }
    return null;
  }

  // These are used to communicate the current configuration between isolates.
  CapturedConfiguration? _capturedConfiguration;
  final ReceivePort _globalRecievePort = ReceivePort(
    'Datadog Isolate Communication Port',
  );

  DatadogSdkMethodChannel() {
    if (!kIsWeb) {
      _initIsolateCommunication();
    }
  }

  @override
  Future<IsolateAttachResponse?> attachToIsolate() {
    // Grab the main instance's send port
    final sendPort = IsolateNameServer.lookupPortByName(
      globalCommunicationPortName,
    );
    if (sendPort != null) {
      final completer = Completer<IsolateAttachResponse>();
      // Listen on my receive port for a response
      _globalRecievePort.first.then((response) {
        if (response is IsolateAttachResponse) {
          BackgroundIsolateBinaryMessenger.ensureInitialized(
            response.rootIsolateToken,
          );
          completer.complete(response);
        } else {
          completer.completeError(DatadogCommunicationError(response));
        }
      });
      sendPort.send(
        _IsolateAttachRequest(sendPort: _globalRecievePort.sendPort),
      );
      return completer.future;
    }
    return Future.value(null);
  }

  @override
  Future<void> setSdkVerbosity(CoreLoggerLevel verbosity) {
    return methodChannel.invokeMethod('setSdkVerbosity', {
      'value': verbosity.toString(),
    });
  }

  @override
  Future<void> setTrackingConsent(TrackingConsent trackingConsent) {
    return methodChannel.invokeMethod('setTrackingConsent', {
      'value': trackingConsent.toString(),
    });
  }

  @override
  Future<void> setUserInfo(
    String id,
    String? name,
    String? email,
    Map<String, Object?> extraInfo,
  ) {
    return methodChannel.invokeMethod('setUserInfo', {
      'id': id,
      'name': name,
      'email': email,
      'extraInfo': extraInfo,
    });
  }

  @override
  Future<void> addUserExtraInfo(Map<String, Object?> extraInfo) {
    return methodChannel.invokeMethod('addUserExtraInfo', {
      'extraInfo': extraInfo,
    });
  }

  @override
  Future<void> clearUserInfo() {
    return methodChannel.invokeMethod('clearUserInfo', {});
  }

  @override
  Future<void> setAccountInfo(
    String id,
    String? name,
    Map<String, Object?> extraInfo,
  ) {
    return methodChannel.invokeMethod('setAccountInfo', {
      'id': id,
      'name': name,
      'extraInfo': extraInfo,
    });
  }

  @override
  Future<void> addAccountExtraInfo(Map<String, Object?> extraInfo) {
    return methodChannel.invokeMethod('addAccountExtraInfo', {
      'extraInfo': extraInfo,
    });
  }

  @override
  Future<void> clearAccountInfo() {
    return methodChannel.invokeMethod('clearAccountInfo', {});
  }

  @override
  Future<PlatformInitializationResult> initialize(
    DatadogConfiguration configuration,
    TrackingConsent trackingConsent, {
    LogCallback? logCallback,
    required InternalLogger internalLogger,
  }) async {
    _logCallback = logCallback;
    methodChannel.setMethodCallHandler(handleMethodCall);

    await methodChannel.invokeMethod<void>('initialize', {
      'configuration': configuration.encode(),
      'trackingConsent': trackingConsent.toString(),
      'dartVersion': Platform.version,
      'setLogCallback': logCallback != null,
    });

    final backgroundPlugins = configuration.additionalPlugins
        .where((e) => e.supportsBackgroundIsolates)
        .toList();

    _capturedConfiguration = CapturedConfiguration(
      loggingEnabled: configuration.loggingConfiguration != null,
      rumEnabled: configuration.rumConfiguration != null,
      traceSampleRate: configuration.rumConfiguration?.traceSampleRate,
      traceContextInjection:
          configuration.rumConfiguration?.traceContextInjection,
      resourceHeadersExtractor:
          configuration.rumConfiguration?.trackResourceHeaders,
      firstPartyHosts: configuration.firstPartyHostsWithTracingHeaders,
      configuredPlugins: backgroundPlugins,
    );

    return const PlatformInitializationResult(logs: true, rum: true);
  }

  @override
  Future<AttachResponse?> attachToExisting(
    DatadogAttachConfiguration attachConfig,
  ) async {
    final channelResponse =
        await methodChannel.invokeMapMethod<String, Object?>(
      'attachToExisting',
      <String, Object?>{},
    );

    AttachResponse? response;
    if (channelResponse != null) {
      response = AttachResponse.decode(channelResponse);
      if (response != null) {
        final backgroundPlugins = attachConfig.additionalPlugins
            .where((e) => e.supportsBackgroundIsolates)
            .toList();
        _capturedConfiguration = CapturedConfiguration(
          loggingEnabled: response.loggingEnabled,
          rumEnabled: response.rumEnabled,
          traceSampleRate: attachConfig.traceSampleRate,
          traceContextInjection: attachConfig.traceContextInjection,
          resourceHeadersExtractor: attachConfig.trackResourceHeaders,
          firstPartyHosts: attachConfig.firstPartyHostsWithTracingHeaders,
          configuredPlugins: backgroundPlugins,
        );
      }
    }
    return response;
  }

  @override
  Future<void> flush() {
    return methodChannel.invokeMethod('flush', <String, Object?>{});
  }

  @override
  Future<void> flushAndDeinitialize() {
    return methodChannel.invokeMethod(
      'flushAndDeinitialize',
      <String, Object?>{},
    );
  }

  @override
  Future<void> sendTelemetryDebug(String message) {
    return methodChannel.invokeMethod('telemetryDebug', {'message': message});
  }

  @override
  Future<void> sendTelemetryError(String message, String? stack, String? kind) {
    return methodChannel.invokeMethod('telemetryError', {
      'message': message,
      'stack': stack,
      'kind': kind,
    });
  }

  @override
  Future<void> updateTelemetryConfiguration(String property, bool value) {
    return methodChannel.invokeMethod('updateTelemetryConfiguration', {
      'option': property,
      'value': value,
    });
  }

  @override
  Future<void> clearAllData() {
    return methodChannel.invokeMethod('clearAllData', {});
  }

  Future<Object?> getInternalVar(String name) {
    return methodChannel.invokeMethod('getInternalVar', {'name': name});
  }

  void _initIsolateCommunication() {
    // If the RootIsolateToken is null, we were started on a background isolate... somehow
    final rootIsolateToken = RootIsolateToken.instance;
    if (rootIsolateToken == null) return;

    IsolateNameServer.registerPortWithName(
      _globalRecievePort.sendPort,
      globalCommunicationPortName,
    );
    _globalRecievePort.listen((message) {
      if (message is _IsolateAttachRequest) {
        if (_capturedConfiguration case final capturedConfiguration?) {
          message.sendPort.send(
            IsolateAttachResponse(
              rootIsolateToken: rootIsolateToken,
              capturedConfiguration: capturedConfiguration,
            ),
          );
        }
      }
    });
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'logCallback':
        _logCallback?.call(call.arguments as String);
        return null;
    }
  }
}
