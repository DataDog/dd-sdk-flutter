// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';
import 'package:msgpack_dart/msgpack_dart.dart';

import '../datadog_internal.dart';
import 'datadog_configuration.dart';
import 'logs/ddlogs_native_core_platform.dart';
import 'logs/ddlogs_platform_interface.dart';

class DatadogNativeCorePlatform extends DatadogSdkPlatform {
  NativeCore? _core;

  @override
  Future<void> addUserExtraInfo(Map<String, Object?> extraInfo) async {}

  @override
  Future<AttachResponse?> attachToExisting() async {
    return null;
  }

  @override
  Future<void> flushAndDeinitialize() async {}

  @override
  Future<void> initialize(DdSdkConfiguration configuration,
      {LogCallback? logCallback,
      required InternalLogger internalLogger}) async {
    using((arena) {
      final coreConfig =
          arena.allocate<CoreConfiguration>(ffi.sizeOf<CoreConfiguration>());
      coreConfig.ref.coreDirectory = 'temp'.toNativeUtf8(allocator: arena);
      coreConfig.ref.clientToken =
          configuration.clientToken.toNativeUtf8(allocator: arena);
      coreConfig.ref.env = configuration.env.toNativeUtf8(allocator: arena);
      coreConfig.ref.service = (configuration.serviceName ?? 'unknown')
          .toNativeUtf8(allocator: arena);

      _core = NativeCore.create(coreConfig);
      if (_core == null) return;

      DdLogsPlatform.instance = DdLogsNativeCorePlatform(_core!);

      if (configuration.loggingConfiguration != null) {
        final loggingConfig = arena.allocate<CoreFeatureConfiguration>(
            ffi.sizeOf<CoreFeatureConfiguration>());
        loggingConfig.ref.name = 'logs'.toNativeUtf8(allocator: arena);
        loggingConfig.ref.endpoint =
            'https://browser-intake-datadoghq.com/api/v2/logs'
                .toNativeUtf8(allocator: arena);
        loggingConfig.ref.uploadFormat.prefix =
            '['.toNativeUtf8(allocator: arena);
        loggingConfig.ref.uploadFormat.suffix =
            ']'.toNativeUtf8(allocator: arena);
        loggingConfig.ref.uploadFormat.separator =
            ','.toNativeUtf8(allocator: arena);

        _core?.createFeature(loggingConfig);
      }
    });
  }

  @override
  Future<void> sendTelemetryDebug(String message) async {}

  @override
  Future<void> sendTelemetryError(
      String message, String? stack, String? kind) async {}

  @override
  Future<void> setSdkVerbosity(Verbosity verbosity) async {}

  @override
  Future<void> setTrackingConsent(TrackingConsent trackingConsent) async {}

  @override
  Future<void> setUserInfo(String? id, String? name, String? email,
      Map<String, Object?> extraInfo) async {}

  @override
  Future<void> updateTelemetryConfiguration(
      String property, bool value) async {}
}

class CoreMessage {
  final String featureTarget;
  final Map<String, String> contextChanges;
  final String messageData;

  CoreMessage({
    required this.featureTarget,
    required this.contextChanges,
    required this.messageData,
  });
}

/// C Interface to Native Core
typedef NativeCorePtr = ffi.Pointer<ffi.Void>;

class CoreConfiguration extends ffi.Struct {
  external ffi.Pointer<Utf8> coreDirectory;
  external ffi.Pointer<Utf8> clientToken;
  external ffi.Pointer<Utf8> env;
  external ffi.Pointer<Utf8> service;
}

class CoreDataUploadFormat extends ffi.Struct {
  external ffi.Pointer<Utf8> prefix;
  external ffi.Pointer<Utf8> suffix;
  external ffi.Pointer<Utf8> separator;
}

class CoreFeatureConfiguration extends ffi.Struct {
  external ffi.Pointer<Utf8> name;
  external ffi.Pointer<Utf8> endpoint;
  external CoreDataUploadFormat uploadFormat;
}

typedef CoreCreateNative = NativeCorePtr Function(
    ffi.Pointer<CoreConfiguration>);
typedef CoreCreate = NativeCorePtr Function(ffi.Pointer<CoreConfiguration>);

typedef CreateFeatureNative = ffi.Void Function(
    NativeCorePtr, ffi.Pointer<CoreFeatureConfiguration> config);
typedef CreateFeature = void Function(
    NativeCorePtr, ffi.Pointer<CoreFeatureConfiguration>);

typedef SendMessageNative = ffi.Uint32 Function(
    NativeCorePtr, ffi.Pointer<ffi.Uint8>, ffi.Size length);
typedef SendMessage = int Function(
    NativeCorePtr, ffi.Pointer<ffi.Uint8>, int size);

@internal
class NativeCore {
  late ffi.DynamicLibrary _dylib;
  NativeCorePtr _corePtr = ffi.nullptr;

  late final _coreCreate = _dylib.lookupFunction<CoreCreateNative, CoreCreate>(
      'datadog_core_create',
      isLeaf: true);

  late final _createFeature =
      _dylib.lookupFunction<CreateFeatureNative, CreateFeature>(
          'datadog_core_create_feature',
          isLeaf: true);

  late final _sendMessage =
      _dylib.lookupFunction<SendMessageNative, SendMessage>(
          'datadog_core_send_message');

  NativeCore._(ffi.Pointer<CoreConfiguration> config) {
    _dylib = _initLibrary();
    _corePtr = _coreCreate(config);
  }

  static NativeCore? create(ffi.Pointer<CoreConfiguration> config) {
    final core = NativeCore._(config);
    if (core._corePtr == ffi.nullptr) return null;
    return core;
  }

  void createFeature(ffi.Pointer<CoreFeatureConfiguration> config) {
    _createFeature(_corePtr, config);
  }

  void sendMessage(CoreMessage message) {
    final serializer = Serializer();
    serializer.encode({
      'feature_target': message.featureTarget,
      'context_changes': message.contextChanges,
      'message_data': message.messageData
    });

    using((arena) {
      final bytes = serializer.takeBytes();
      final dataPtr = arena.allocate<ffi.Uint8>(bytes.length);
      final typed = dataPtr.asTypedList(bytes.length);
      typed.setAll(0, bytes);

      _sendMessage(_corePtr, dataPtr, bytes.length);
    });
  }

  static ffi.DynamicLibrary _initLibrary() {
    var libraryPath = 'libdd_native_rum.so';
    if (Platform.isMacOS) {
      libraryPath = 'libdd_native_rum.dylib';
    } else if (Platform.isWindows) {
      libraryPath = 'dd_native_rum.dll';
    }
    return ffi.DynamicLibrary.open(libraryPath);
  }
}
