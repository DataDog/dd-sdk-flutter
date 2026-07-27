// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:datadog_flutter_plugin_platform_interface/datadog_flutter_plugin_platform_interface.dart';
import 'package:datadog_flutter_plugin_platform_interface/datadog_internal.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'attribute_builder.dart';
import 'ffi_bindings.dart';
import 'logs_desktop_platform.dart';
import 'native_char.dart';
import 'rum_desktop_platform.dart';

const String _kIsolatePortName = 'dd_flutter_desktop_sdk';

@immutable
class _IsolateAttachRequest {
  final SendPort sendPort;
  const _IsolateAttachRequest({required this.sendPort});
}

@immutable
class _DesktopIsolateAttachResponse {
  final IsolateAttachResponse isolateAttachResponse;
  final int coreAddress;
  final int loggingAddress;
  final int rumAddress;

  const _DesktopIsolateAttachResponse({
    required this.isolateAttachResponse,
    required this.coreAddress,
    required this.loggingAddress,
    required this.rumAddress,
  });
}

class DatadogDesktopPlatform extends DatadogSdkPlatform {
  final DdSdkFfi _sdk;
  ffi.Pointer<dd_core>? _core;
  ffi.Pointer<dd_logging>? _logging;
  ffi.Pointer<dd_rum>? _rum;
  InternalLogger? _internalLogger;

  ReceivePort? _isolateConfigPort;
  RootIsolateToken? _rootIsolateToken;
  CapturedConfiguration? _capturedConfig;

  // Kept alive so the C shim's function pointer remains valid for the SDK's lifetime.
  ffi.NativeCallable<_DiagnosticCallbackNative>? _diagnosticCallable;

  DatadogDesktopPlatform(this._sdk);

  ffi.DynamicLibrary? _pluginLib;

  @override
  Future<PlatformInitializationResult> initialize(
    DatadogConfiguration configuration,
    TrackingConsent trackingConsent, {
    LogCallback? logCallback,
    required InternalLogger internalLogger,
  }) async {
    _internalLogger = internalLogger;
    _core = using((arena) {
      final cfg = arena<dd_core_config>();
      _sdk.dd_core_config_init(
        cfg,
        configuration.clientToken.toNativeChar(allocator: arena),
        (configuration.service ?? _defaultServiceName()).toNativeChar(
          allocator: arena,
        ),
        configuration.env.toNativeChar(allocator: arena),
      );

      // Although `flutter run` will output stderr under normal conditions, it
      // will not forward that output to other processes (like `flutter test`)
      // or to IDEs. For that reason we override the diagnostic output of the C++
      // SDK and set the threshold to match the SDK verbosity at initialization time.
      _sdk.dd_core_config_set_diagnostic_threshold(
        cfg,
        _verbosityToC(internalLogger.sdkVerbosity),
      );

      // Don't bother overriding diagnostic output outside of kDebugMode, as we don't
      // want t to print outside of debug mode.
      if (kDebugMode) {
        _pluginLib = _openPluginLibrary(internalLogger);
        if (_pluginLib case final pluginLib?) {
          try {
            _pluginFree = pluginLib
                .lookupFunction<_DdFlutterFreeNative, _DdFlutterFreeDart>(
                  'dd_flutter_free',
                );
            _diagnosticCallable =
                ffi.NativeCallable<_DiagnosticCallbackNative>.listener(
                  _onDiagnostic,
                );
            pluginLib.lookupFunction<_SetListenerNative, _SetListenerDart>(
              'dd_flutter_set_diagnostic_listener',
            )(_diagnosticCallable!.nativeFunction);
            final handler = pluginLib
                .lookup<ffi.NativeFunction<_DiagnosticHandlerNative>>(
                  'dd_flutter_diagnostic_handler',
                );
            _sdk.dd_core_config_set_diagnostic_handler(cfg, handler);
          } catch (e, st) {
            internalLogger.warn("Could not setup SDK diagnostic logging.");
            internalLogger.sendToDatadog(
              "Error setting up SDK diagnostic logging: $e",
              st,
              e.runtimeType.toString(),
            );
          }
        }
      }

      _sdk.dd_core_config_set_site(cfg, _siteToC(configuration.site));

      final storagePath = _storagePath(configuration.service ?? 'datadog');
      Directory(storagePath).createSync(recursive: true);
      _sdk.dd_core_config_set_application_storage_path(
        cfg,
        storagePath.toNativeChar(allocator: arena),
      );

      final additionalConfig = configuration.additionalConfig;

      final source = additionalConfig[DatadogConfigKey.source] as String?;
      if (source != null) {
        _sdk.dd_core_config_internal_set_source(
          cfg,
          source.toNativeChar(allocator: arena),
        );
      }
      final sdkVersion =
          additionalConfig[DatadogConfigKey.sdkVersion] as String?;
      if (sdkVersion != null) {
        _sdk.dd_core_config_internal_set_sdk_version(
          cfg,
          sdkVersion.toNativeChar(allocator: arena),
        );
      }
      final version =
          configuration.versionTag ??
          additionalConfig[DatadogConfigKey.version] as String?;
      if (version != null) {
        _sdk.dd_core_config_set_version(
          cfg,
          version.toNativeChar(allocator: arena),
        );
      }
      final variant =
          configuration.flavor ??
          additionalConfig[DatadogConfigKey.variant] as String?;
      if (variant != null) {
        _sdk.dd_core_config_set_variant(
          cfg,
          variant.toNativeChar(allocator: arena),
        );
      }
      if (configuration.batchSize != null) {
        _sdk.dd_core_config_set_batch_size(
          cfg,
          _batchSizeToC(configuration.batchSize!),
        );
      }
      if (configuration.uploadFrequency != null) {
        _sdk.dd_core_config_set_upload_frequency(
          cfg,
          _uploadFreqToC(configuration.uploadFrequency!),
        );
      }
      if (configuration.batchProcessingLevel != null) {
        _sdk.dd_core_config_set_batch_processing_level(
          cfg,
          _batchLevelToC(configuration.batchProcessingLevel!),
        );
      }
      final customEndpoint =
          configuration.rumConfiguration?.customEndpoint ??
          configuration.loggingConfiguration?.customEndpoint;
      if (customEndpoint != null) {
        _sdk.dd_core_config_internal_set_custom_endpoint_url(
          cfg,
          _toEndpointBase(customEndpoint).toNativeChar(allocator: arena),
        );
      }

      return _sdk.dd_core_create(cfg, _consentToC(trackingConsent));
    });

    if (_core == null || _core!.address == 0) {
      internalLogger.warn("Failure setting up Datadog Core.");
      return PlatformInitializationResult(logs: false, rum: false);
    }

    // Features must be registered BEFORE dd_core_start.
    ffi.Pointer<dd_logging>? logging;
    ffi.Pointer<dd_rum>? rum;

    if (configuration.loggingConfiguration != null) {
      logging = _sdk.dd_logging_init(_core!);
    }

    if (configuration.rumConfiguration case final rumConfig?) {
      rum = using((arena) {
        final cfg = arena<dd_rum_config>();
        _sdk.dd_rum_config_init(
          cfg,
          rumConfig.applicationId.toNativeChar(allocator: arena),
        );
        if (rumConfig.sessionSamplingRate != 100.0) {
          _sdk.dd_rum_config_set_session_sample_rate(
            cfg,
            rumConfig.sessionSamplingRate.toDouble(),
          );
        }
        return _sdk.dd_rum_init(_core!, cfg);
      });
    }

    if (!_sdk.dd_core_start(_core!)) {
      internalLogger.warn("Failure setting up Datadog Core.");
      return PlatformInitializationResult(logs: false, rum: false);
    }

    bool logsEnabled = false;
    bool rumEnabled = false;

    if (logging != null && logging.address != 0) {
      _logging = logging;
      DdLogsPlatform.instance = DdLogsDesktopPlatform(_sdk, logging);
      logsEnabled = true;
    }

    if (rum != null && rum.address != 0) {
      _rum = rum;
      DdRumPlatform.instance = DdRumDesktopPlatform(_sdk, rum);
      rumEnabled = true;
    }

    _rootIsolateToken = RootIsolateToken.instance;
    final backgroundPlugins = configuration.additionalPlugins
        .where((e) => e.supportsBackgroundIsolates)
        .toList();
    _capturedConfig = CapturedConfiguration(
      loggingEnabled: logsEnabled,
      rumEnabled: rumEnabled,
      traceSampleRate: configuration.rumConfiguration?.traceSampleRate,
      traceContextInjection:
          configuration.rumConfiguration?.traceContextInjection,
      resourceHeadersExtractor:
          configuration.rumConfiguration?.trackResourceHeaders,
      firstPartyHosts: configuration.firstPartyHostsWithTracingHeaders,
      configuredPlugins: backgroundPlugins,
    );
    _isolateConfigPort = ReceivePort();
    _isolateConfigPort!.listen(_handleIsolateConfigRequest);
    IsolateNameServer.registerPortWithName(
      _isolateConfigPort!.sendPort,
      _kIsolatePortName,
    );

    return PlatformInitializationResult(logs: logsEnabled, rum: rumEnabled);
  }

  void _handleIsolateConfigRequest(dynamic message) {
    if (message is! _IsolateAttachRequest) return;
    final token = _rootIsolateToken;
    final config = _capturedConfig;
    if (token == null || config == null) return;
    message.sendPort.send(
      _DesktopIsolateAttachResponse(
        isolateAttachResponse: IsolateAttachResponse(
          rootIsolateToken: token,
          capturedConfiguration: config,
        ),
        coreAddress: _core?.address ?? 0,
        loggingAddress: _logging?.address ?? 0,
        rumAddress: _rum?.address ?? 0,
      ),
    );
  }

  @override
  Future<AttachResponse?> attachToExisting(
    DatadogAttachConfiguration attachConfig,
  ) async => null;

  @override
  Future<IsolateAttachResponse?> attachToIsolate() async {
    final configPort = IsolateNameServer.lookupPortByName(_kIsolatePortName);
    if (configPort == null) return null;

    final responsePort = ReceivePort();
    configPort.send(_IsolateAttachRequest(sendPort: responsePort.sendPort));
    final response =
        await responsePort.first.timeout(
              Duration(seconds: 1),
              onTimeout: () {
                return null;
              },
            )
            as _DesktopIsolateAttachResponse?;
    responsePort.close();

    if (response == null) {
      return null;
    }

    if (response.coreAddress == 0) return null;
    _core = ffi.Pointer<dd_core>.fromAddress(response.coreAddress);

    if (response.loggingAddress != 0) {
      _logging = ffi.Pointer<dd_logging>.fromAddress(response.loggingAddress);
      DdLogsPlatform.instance = DdLogsDesktopPlatform(_sdk, _logging!);
    }

    if (response.rumAddress != 0) {
      _rum = ffi.Pointer<dd_rum>.fromAddress(response.rumAddress);
      DdRumPlatform.instance = DdRumDesktopPlatform(_sdk, _rum!);
    }

    return response.isolateAttachResponse;
  }

  @override
  DatadogContext? getContext() => null;

  @override
  Future<void> setSdkVerbosity(CoreLoggerLevel verbosity) async {
    _internalLogger?.warn(
      'setSdkVerbosity is not supported on Desktop platforms after initialization.',
    );
  }

  @override
  Future<void> setTrackingConsent(TrackingConsent trackingConsent) async {
    final core = _core;
    if (core == null) return;

    _sdk.dd_core_set_tracking_consent(core, _consentToC(trackingConsent));
  }

  @override
  Future<void> setUserInfo(
    String id,
    String? name,
    String? email,
    Map<String, Object?> extraInfo,
  ) async {
    final core = _core;
    if (core == null) return;

    using((arena) {
      _sdk.dd_core_set_user_info(
        core,
        id.toNativeChar(allocator: arena),
        name.toNativeChar(allocator: arena),
        email.toNativeChar(allocator: arena),
        buildAttrObject(extraInfo, arena, _sdk),
      );
    });
  }

  @override
  Future<void> clearUserInfo() async {
    final core = _core;
    if (core == null) return;

    _sdk.dd_core_clear_user_info(core);
  }

  @override
  Future<void> addUserExtraInfo(Map<String, Object?> extraInfo) async {
    final core = _core;
    if (core == null || extraInfo.isEmpty) return;

    using((arena) {
      _sdk.dd_core_add_user_extra_info(
        core,
        buildAttrObject(extraInfo, arena, _sdk),
      );
    });
  }

  @override
  Future<void> setAccountInfo(
    String id,
    String? name,
    Map<String, Object?> extraInfo,
  ) async {
    final core = _core;
    if (core == null) return;
    using((arena) {
      _sdk.dd_core_set_account_info(
        core,
        id.toNativeChar(allocator: arena),
        name.toNativeChar(allocator: arena),
        buildAttrObject(extraInfo, arena, _sdk),
      );
    });
  }

  @override
  Future<void> clearAccountInfo() async {
    final core = _core;
    if (core == null) return;

    _sdk.dd_core_clear_account_info(core);
  }

  @override
  Future<void> addAccountExtraInfo(Map<String, Object?> extraInfo) async {
    final core = _core;
    if (core == null || extraInfo.isEmpty) return;

    using((arena) {
      _sdk.dd_core_add_account_extra_info(
        core,
        buildAttrObject(extraInfo, arena, _sdk),
      );
    });
  }

  @override
  Future<void> sendTelemetryDebug(String message) async {}

  @override
  Future<void> sendTelemetryError(
    String message,
    String? stack,
    String? kind,
  ) async {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> flushAndDeinitialize() async {
    final core = _core;
    if (core == null) return;
    _sdk.dd_core_stop(core);
    _sdk.dd_core_destroy(core);
    _core = null;
    _logging = null;
    _rum = null;
    _diagnosticCallable?.close();
    _diagnosticCallable = null;
    _pluginFree = null;
    IsolateNameServer.removePortNameMapping(_kIsolatePortName);
    _isolateConfigPort?.close();
    _isolateConfigPort = null;
    _capturedConfig = null;
    _rootIsolateToken = null;
  }

  @override
  Future<void> clearAllData() async {}

  @override
  Future<void> updateTelemetryConfiguration(
    String property,
    bool value,
  ) async {}

  // The C SDK takes a base URL and appends /api/v2/rum, /api/v2/logs, etc. itself.
  // Strip any trailing slash (C SDK validation rejects URLs ending with /).
  // Replace 'localhost' with '127.0.0.1' to force IPv4 and avoid resolution
  // to ::1 (IPv6) which may not be reachable if the server binds IPv4 only.
  String _toEndpointBase(String endpoint) {
    var base = endpoint.replaceFirst('localhost', '127.0.0.1');
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  String _defaultServiceName() {
    var name = Platform.resolvedExecutable.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    return name;
  }

  String _storagePath(String service) {
    if (Platform.isWindows) {
      final base = Platform.environment['LOCALAPPDATA'] ?? '.';
      return '$base\\Datadog\\$service';
    }
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.local/share/datadog/$service';
  }

  int _verbosityToC(CoreLoggerLevel verbosity) {
    switch (verbosity) {
      case CoreLoggerLevel.debug:
        return dd_diagnostic_level_t.DD_DIAGNOSTIC_LEVEL_DEBUG;
      case CoreLoggerLevel.warn:
        return dd_diagnostic_level_t.DD_DIAGNOSTIC_LEVEL_WARNING;
      case CoreLoggerLevel.error:
      case CoreLoggerLevel.critical:
        return dd_diagnostic_level_t.DD_DIAGNOSTIC_LEVEL_ERROR;
    }
  }

  int _siteToC(DatadogSite site) {
    switch (site) {
      case DatadogSite.us1:
        return dd_site_t.DD_SITE_US1;
      case DatadogSite.us3:
        return dd_site_t.DD_SITE_US3;
      case DatadogSite.us5:
        return dd_site_t.DD_SITE_US5;
      case DatadogSite.eu1:
        return dd_site_t.DD_SITE_EU1;
      case DatadogSite.us1Fed:
        return dd_site_t.DD_SITE_US1_FED;
      case DatadogSite.ap1:
        return dd_site_t.DD_SITE_AP1;
      case DatadogSite.ap2:
        return dd_site_t.DD_SITE_AP2;
    }
  }

  int _consentToC(TrackingConsent consent) {
    switch (consent) {
      case TrackingConsent.granted:
        return dd_tracking_consent_t.DD_TRACKING_CONSENT_GRANTED;
      case TrackingConsent.notGranted:
        return dd_tracking_consent_t.DD_TRACKING_CONSENT_NOT_GRANTED;
      case TrackingConsent.pending:
        return dd_tracking_consent_t.DD_TRACKING_CONSENT_PENDING;
    }
  }

  int _batchSizeToC(BatchSize size) {
    switch (size) {
      case BatchSize.small:
        return dd_batch_size_t.DD_BATCH_SIZE_SMALL;
      case BatchSize.medium:
        return dd_batch_size_t.DD_BATCH_SIZE_MEDIUM;
      case BatchSize.large:
        return dd_batch_size_t.DD_BATCH_SIZE_LARGE;
    }
  }

  int _uploadFreqToC(UploadFrequency freq) {
    switch (freq) {
      case UploadFrequency.frequent:
        return dd_upload_frequency_t.DD_UPLOAD_FREQUENCY_FREQUENT;
      case UploadFrequency.average:
        return dd_upload_frequency_t.DD_UPLOAD_FREQUENCY_AVERAGE;
      case UploadFrequency.rare:
        return dd_upload_frequency_t.DD_UPLOAD_FREQUENCY_RARE;
    }
  }

  int _batchLevelToC(BatchProcessingLevel level) {
    switch (level) {
      case BatchProcessingLevel.low:
        return dd_batch_processing_level_t.DD_BATCH_PROCESSING_LEVEL_LOW;
      case BatchProcessingLevel.medium:
        return dd_batch_processing_level_t.DD_BATCH_PROCESSING_LEVEL_MEDIUM;
      case BatchProcessingLevel.high:
        return dd_batch_processing_level_t.DD_BATCH_PROCESSING_LEVEL_HIGH;
    }
  }

  static ffi.DynamicLibrary? _openPluginLibrary(InternalLogger internalLogger) {
    try {
      const String pluginLibraryName = "datadog_flutter_plugin_desktop_plugin";
      final lib = Platform.isWindows
          ? ffi.DynamicLibrary.open("$pluginLibraryName.dll")
          : ffi.DynamicLibrary.open("lib$pluginLibraryName.so");
      return lib;
    } catch (e, st) {
      internalLogger.warn(
        "Could not find desktop plugin library to initialize SDK diagnostic logging.",
      );
      internalLogger.sendToDatadog(
        "Could not find desktop plugin library to initialize SDK diagnostic logging: $e",
        st,
        e.runtimeType.toString(),
      );
    }
    return null;
  }
}

// FFI typedefs
typedef _DiagnosticCallbackNative =
    ffi.Void Function(ffi.Int32, ffi.Pointer<ffi.Char>);

typedef _DdFlutterFreeNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _DdFlutterFreeDart = void Function(ffi.Pointer<ffi.Void>);

typedef _SetListenerNative =
    ffi.Void Function(
      ffi.Pointer<ffi.NativeFunction<_DiagnosticCallbackNative>>,
    );
typedef _SetListenerDart =
    void Function(ffi.Pointer<ffi.NativeFunction<_DiagnosticCallbackNative>>);

typedef _DiagnosticHandlerNative =
    ffi.Void Function(
      ffi.Pointer<dd_diagnostic_message_t>,
      ffi.Pointer<ffi.Void>,
    );

// Holds the dd_flutter_free function from the plugin shim DLL.
// Set before _diagnosticCallable is created; read by the top-level _onDiagnostic.
// Must use the shim's own free() — cross-DLL heap frees crash on Windows.
void Function(ffi.Pointer<ffi.Void>)? _pluginFree;

// Top-level required by NativeCallable.listener (no closures over Dart objects).
// Receives a _strdup copy of the diagnostic text from the C shim; frees it via
// dd_flutter_free so the deallocation uses the same CRT heap as the allocation.
void _onDiagnostic(int level, ffi.Pointer<ffi.Char> text) {
  const levels = ['DEBUG', 'STATUS', 'WARNING', 'ERROR'];
  final levelStr = (level >= 0 && level < levels.length) ? levels[level] : '?';
  final message = text.cast<Utf8>().toDartString();
  _pluginFree?.call(text.cast());
  if (kDebugMode) {
    print('[DATADOG $levelStr] $message');
  }
}
