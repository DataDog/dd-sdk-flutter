// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2024-Present Datadog, Inc.
import 'package:dio/dio.dart';

import 'abstract_client.dart';

class DioClient extends AbstractClient {
  final Dio dio = Dio();

  @override
  Future<int> get(Uri uri, {Map<String, String>? headers}) async {
    final response = await dio.getUri(uri, options: Options(headers: headers));
    return response.statusCode!;
  }

  @override
  Future<int> post(Uri uri) async {
    final response = await dio.postUri(uri);
    return response.statusCode!;
  }
}
