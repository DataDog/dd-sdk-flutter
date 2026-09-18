// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import '../../datadog_common_test.dart';

class LogDecoder {
  final Map<String, Object?> log;

  LogDecoder(this.log);

  // static const date = 'date';
  String get status => log['status'] as String;
  String get message => log['message'] as String;
  String get serviceName => log['service'] as String;
  String get tags => log['ddtags'] as String;

  String? get userAnonymousId => getNestedProperty('usr.anonymous_id', log);
  String? get userId => getNestedProperty('usr.id', log);
  String? get userName => getNestedProperty('usr.name', log);
  String? get userEmail => getNestedProperty('usr.email', log);
  String? get accountId => getNestedProperty('account.id', log);
  String? get accountName => getNestedProperty('account.name', log);

  List<String> get tagValues => (log['ddtags'] as String).split(',');
  String get applicationVersion => log['version'] as String;
  String get loggerName => getNestedProperty('logger.name', log);
  String get loggerVersion => getNestedProperty('logger.version', log);
  String get threadName => getNestedProperty('logger.thread_name', log);
  String get errorKind => getNestedProperty('error.kind', log);
  String get errorMessage => getNestedProperty('error.message', log);
  String get errorStack => getNestedProperty('error.stack', log);
  String get errorSourceType => getNestedProperty('error.source_type', log);
  String? get errorFingerprint {
    if (!kManualIsWeb) {
      return getNestedProperty('error.fingerprint', log);
    } else {
      return log['error.fingerprint'] as String?;
    }
  }

  Object? getUserProperty(String name) {
    return getNestedProperty('usr.$name', log);
  }

  Object? getAccountProperty(String name) {
    return getNestedProperty('account.$name', log);
  }
}
