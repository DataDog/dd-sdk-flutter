// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:io';

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
class ErrorTypeResolverRegistry {
  final List<ErrorTypeResolver> _resolvers = [];

  /// Adds [resolver] to the end of the list of resolvers. Adding a resolver
  /// that is already registered does nothing.
  void add(ErrorTypeResolver resolver) {
    if (!_resolvers.contains(resolver)) {
      _resolvers.add(resolver);
    }
  }

  /// Returns the first non-null type returned by the registered resolvers, in
  /// the order they were added, then by [defaultErrorTypeResolver], or `null`
  /// if no resolver knows [error].
  ///
  /// A resolver that throws is skipped.
  String? tryResolve(Object error) {
    for (final resolver in _resolvers) {
      try {
        final type = resolver(error);
        if (type != null) {
          return type;
        }
      } catch (_) {
        // Ignore failing resolvers, reporting the error matters more.
      }
    }
    return defaultErrorTypeResolver(error);
  }

  /// Same as [tryResolve], but falls back to `error.runtimeType.toString()` if
  /// no resolver knows [error].
  String resolve(Object error) =>
      tryResolve(error) ?? error.runtimeType.toString();
}
