// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2024-Present Datadog, Inc.
import 'dart:convert';
import 'dart:io';

import 'abstract_client.dart';

class IoClient extends AbstractClient {
  final client = HttpClient();

  @override
  Future<int> get(Uri uri, {Map<String, String>? headers}) async {
    final request = await client.getUrl(uri);
    if (headers != null) {
      for (final header in headers.entries) {
        request.headers.add(header.key, header.value);
      }
    }

    final response = await request.close();
    final _ = await response.transform(utf8.decoder).join();
    return response.statusCode;
  }

  @override
  Future<int> post(Uri uri) async {
    final request = await client.postUrl(uri);
    final response = await request.close();
    final _ = await response.transform(utf8.decoder).join();
    return response.statusCode;
  }
}
