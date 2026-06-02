// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'assignment.dart';
import 'flags_context.dart';

abstract class DatadogFlagsStore {
  Future<FlagsData?> read(String clientName);
  Future<void> write(String clientName, FlagsData data);
  Future<void> delete(String clientName);
}

class FlagsData {
  final Map<String, FlagAssignment> flags;
  final DatadogFlagsEvaluationContext context;
  final DateTime date;

  const FlagsData({
    required this.flags,
    required this.context,
    required this.date,
  });

  factory FlagsData.fromJson(Map<String, Object?> json) {
    final flags = json['flags'] as Map<String, Object?>? ?? const {};
    return FlagsData(
      flags: flags.map((key, value) {
        return MapEntry(
          key,
          FlagAssignment.fromJson(value as Map<String, Object?>),
        );
      }),
      context: DatadogFlagsEvaluationContext.fromJson(
        json['context'] as Map<String, Object?>,
      ),
      date: DateTime.parse(json['date'] as String),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'flags': flags.map((key, value) => MapEntry(key, value.toJson())),
      'context': context.toJson(),
      'date': date.toIso8601String(),
    };
  }
}

class SharedPreferencesDatadogFlagsStore implements DatadogFlagsStore {
  final SharedPreferences sharedPreferences;
  final String namespace;

  SharedPreferencesDatadogFlagsStore({
    required this.sharedPreferences,
    this.namespace = 'datadog_flags',
  });

  @override
  Future<FlagsData?> read(String clientName) async {
    final encoded = sharedPreferences.getString(_key(clientName));
    if (encoded == null) {
      return null;
    }
    final decoded = jsonDecode(encoded) as Map<String, Object?>;
    return FlagsData.fromJson(decoded);
  }

  @override
  Future<void> write(String clientName, FlagsData data) {
    return sharedPreferences.setString(
      _key(clientName),
      jsonEncode(data.toJson()),
    );
  }

  @override
  Future<void> delete(String clientName) {
    return sharedPreferences.remove(_key(clientName));
  }

  String _key(String clientName) => '$namespace.$clientName';
}

class InMemoryDatadogFlagsStore implements DatadogFlagsStore {
  final Map<String, FlagsData> values = {};

  @override
  Future<FlagsData?> read(String clientName) async => values[clientName];

  @override
  Future<void> write(String clientName, FlagsData data) async {
    values[clientName] = data;
  }

  @override
  Future<void> delete(String clientName) async {
    values.remove(clientName);
  }
}
