// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:meta/meta.dart';

import 'internal_logger.dart';
import 'tracing/tracing_headers.dart';

String? sanitizeHost(String host, InternalLogger internalLogger) {
  final uri = Uri.tryParse(host);
  if (uri != null) {
    if (uri.hasScheme) {
      internalLogger.warn(
        '$host is a url and will be sanitized to: ${uri.host}.',
      );
      host = uri.host;
    }

    return host;
  }

  internalLogger.warn('$host is a not a valid url and will be dropped');
  return null;
}

/// Used to attach a first party host name to what headers should be
/// automatically attached by RUM Http Tracking
@immutable
class FirstPartyHost {
  final String hostName;
  final Set<TracingHeaderType> headerTypes;

  final RegExp regExp;

  FirstPartyHost._(this.hostName, this.headerTypes)
      : regExp = RegExp('^(.*\\.)*${RegExp.escape(hostName)}\$');

  bool matches(Uri uri) {
    return regExp.hasMatch(uri.host.toString());
  }

  static List<FirstPartyHost> createSanitized(
    Map<String, Set<TracingHeaderType>> hosts,
    InternalLogger logger,
  ) {
    var firstPartyHosts = <FirstPartyHost>[];
    for (var entry in hosts.entries) {
      var sanitizedHost = sanitizeHost(entry.key, logger);
      if (sanitizedHost != null) {
        firstPartyHosts.add(FirstPartyHost._(sanitizedHost, entry.value));
      }
    }

    return firstPartyHosts;
  }
}
