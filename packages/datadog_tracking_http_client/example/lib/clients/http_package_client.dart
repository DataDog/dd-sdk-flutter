// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2024-Present Datadog, Inc.
import 'package:http/http.dart' as http;

import 'abstract_client.dart';

class HttpPackageClient extends AbstractClient {
  final http.Client client;

  HttpPackageClient(this.client);

  @override
  Future<int> get(Uri uri, {Map<String, String>? headers}) async {
    final response = await client.get(uri, headers: headers);
    return response.statusCode;
  }

  @override
  Future<int> post(Uri uri) async {
    final response = await client.post(uri);
    return response.statusCode;
  }
}
