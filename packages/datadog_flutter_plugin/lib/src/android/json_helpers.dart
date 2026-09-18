// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:convert';

import 'package:jni/jni.dart';

import '../../datadog_internal.dart';

Map<String, dynamic>? safeDecodeJavaJson(JString json, InternalLogger logger) {
  try {
    final jsonString = json.toDartString();
    return jsonDecode(jsonString) as Map<String, dynamic>;
  } catch (e, st) {
    logger.error('Error performing mapping deserialization: $e');
    logger.sendToDatadog(e.toString(), st, e.runtimeType.toString());
  }
  return null;
}

JString? safeEncodeJavaJson(
  Map<String, dynamic>? encoded,
  InternalLogger logger, {
  required JString? fallback,
}) {
  if (encoded == null) return null;

  try {
    String json = jsonEncode(encoded);
    return JString.fromString(json);
  } catch (e, st) {
    logger.error('Error performing mapping deserialization: $e');
    logger.sendToDatadog(e.toString(), st, e.runtimeType.toString());
  }
  return fallback;
}
