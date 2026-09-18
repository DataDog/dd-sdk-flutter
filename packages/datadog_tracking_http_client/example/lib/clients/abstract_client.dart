// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2024-Present Datadog, Inc.

abstract class AbstractClient {
  Future<int> get(Uri uri, {Map<String, String>? headers});
  Future<int> post(Uri uri);
}
