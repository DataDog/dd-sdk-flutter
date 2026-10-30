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
/// See [DatadogSdk.addErrorTypeResolver].
typedef ErrorTypeResolver = String? Function(Object error);

/// Resolves the type of common Dart exceptions that are not affected by
/// obfuscation.
///
/// This matches exact types only, so subclasses of these types report their
/// own `runtimeType`, which is obfuscated in apps built with `--obfuscate`.
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
  /// A resolver that throws is logged and skipped.
  String? tryResolve(Object error) {
    for (final resolver in [..._appResolvers, ..._integrationResolvers]) {
      try {
        final type = resolver(error);
        if (type != null) {
          return type;
        }
      } catch (e) {
        _logger.warn('An error type resolver threw an exception: $e');
      }
    }
    return defaultErrorTypeResolver(error);
  }

  /// Same as [tryResolve], but falls back to `error.runtimeType.toString()` if
  /// no resolver knows [error].
  String resolve(Object error) =>
      tryResolve(error) ?? error.runtimeType.toString();
}
