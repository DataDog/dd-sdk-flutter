// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

class LogDecoder {
  final Map<String, Object?> log;

  LogDecoder(this.log);

  // static const date = 'date';
  String get status => log['status'] as String;
  String get message => log['message'] as String;
  String get serviceName => log['service'] as String;
  String get tags => log['ddtags'] as String;
  String get applicationVersion => log['version'] as String;
  String get loggerName => log['logger.name'] as String;
  String get loggerVersion => log['logger.version'] as String;
  String get threadName => log['logger.thread_name'] as String;
}
