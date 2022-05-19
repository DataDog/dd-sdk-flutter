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
  String get applicationVersion => log['version'] as String;
  String get loggerName => getNestedProperty('logger.name', log);
  String get loggerVersion => getNestedProperty('logger.version', log);
  String get threadName => getNestedProperty('logger.thread_name', log);
}
