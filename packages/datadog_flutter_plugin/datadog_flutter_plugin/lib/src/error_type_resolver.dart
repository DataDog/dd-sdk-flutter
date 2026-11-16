// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:io';

import 'package:datadog_flutter_plugin_platform_interface/datadog_internal.dart';

/// A function that returns a stable name for the type of [error], or `null`
/// if it does not know the type of [error].
///
/// When an app is built with `--obfuscate`, `error.runtimeType.toString()`
/// returns an obfuscated name that changes with every build, which breaks
/// error grouping and any monitor or facet on `@error.type`. Comparing types
/// (`error.runtimeType == SomeType` or `error is SomeType`) is not affected by
/// obfuscation, so resolvers can use these checks to return a name from a
/// string literal instead.
///
/// Resolvers should return the same name `runtimeType.toString()` returns in
/// an unobfuscated build, so the reported type is the same in obfuscated and
/// unobfuscated builds.
///
/// A resolver can use any logic to name an error. The resolvers provided by
/// the SDK and its integration packages match exact types only, so subclasses
/// of the types they know, and any type without a resolver, report their
/// `runtimeType`. Register resolvers for the types your app reports with
/// [DatadogSdk.addErrorTypeResolver]:
///
/// ```dart
/// String? myErrorTypeResolver(Object error) {
///   return switch (error.runtimeType) {
///     const (PaymentException) => 'PaymentException',
///     _ => null,
///   };
/// }
///
/// DatadogSdk.instance.addErrorTypeResolver(myErrorTypeResolver);
/// ```
///
/// Each isolate has its own [DatadogSdk] instance, so resolvers registered in
/// the main isolate are not available in background isolates. Register them
/// again after attaching to the background isolate:
///
/// ```dart
/// await DatadogSdk.instance.attachToBackgroundIsolate();
/// DatadogSdk.instance.addErrorTypeResolver(myErrorTypeResolver);
/// ```
///
/// Integration packages register their resolvers when they are created, so
/// they are available in any isolate that creates them.
///
/// If a resolver throws, the exception is logged and the next resolver is
/// used.
typedef ErrorTypeResolver = String? Function(Object error);

/// Resolves the type of common Dart exceptions.
///
/// This matches exact types only, so subclasses of these types report their
/// own `runtimeType`.
String? defaultErrorTypeResolver(Object error) {
  return switch (error.runtimeType) {
    const (TimeoutException) => 'TimeoutException',
    const (FormatException) => 'FormatException',
    const (SocketException) => 'SocketException',
    const (HttpException) => 'HttpException',
    const (WebSocketException) => 'WebSocketException',
    const (HandshakeException) => 'HandshakeException',
    const (CertificateException) => 'CertificateException',
    const (TlsException) => 'TlsException',
    const (OSError) => 'OSError',
    _ => null,
  };
}

/// Holds the [ErrorTypeResolver]s registered with the SDK.
///
/// Resolvers added by the app run before resolvers added by integration
/// packages, so an app can override the type an integration reports no matter
/// which one is registered first.
class ErrorTypeResolverRegistry {
  final InternalLogger _logger;
  final List<ErrorTypeResolver> _appResolvers = [];
  final List<ErrorTypeResolver> _integrationResolvers = [];

  ErrorTypeResolverRegistry(this._logger);

  /// Adds an app [resolver] to the end of the list of app resolvers. Adding a
  /// resolver that is already registered does nothing.
  void add(ErrorTypeResolver resolver) {
    if (!_appResolvers.contains(resolver)) {
      _appResolvers.add(resolver);
    }
  }

  /// Adds an integration [resolver] to the end of the list of integration
  /// resolvers. Adding a resolver that is already registered does nothing.
  void addIntegration(ErrorTypeResolver resolver) {
    if (!_integrationResolvers.contains(resolver)) {
      _integrationResolvers.add(resolver);
    }
  }

  /// Returns the first non-null type returned by the app resolvers, then by
  /// the integration resolvers, each in the order they were added, then by
  /// [defaultErrorTypeResolver], or `null` if no resolver knows [error].
  ///
  /// A resolver that throws is logged, reported to Datadog's telemetry and
  /// skipped.
  String? tryResolve(Object error) {
    for (final resolver in [..._appResolvers, ..._integrationResolvers]) {
      try {
        final type = resolver(error);
        if (type != null) {
          return type;
        }
      } catch (e, st) {
        final message = 'An error type resolver threw an exception: $e';
        _logger.warn(message);
        _logger.sendToDatadog(message, st, e.runtimeType.toString());
      }
    }
    return defaultErrorTypeResolver(error);
  }

  /// Same as [tryResolve], but falls back to `error.runtimeType.toString()` if
  /// no resolver knows [error].
  String resolve(Object error) =>
      tryResolve(error) ?? error.runtimeType.toString();
}
