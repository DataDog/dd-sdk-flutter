// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:async';

import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';

class DatadogGqlLink extends Link {
  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    assert(
      forward != null,
      'DatadogGqlLink is not a terminating link and needs a NextLink',
    );

    return forward!(request).transform(StreamTransformer.fromHandlers(
      handleData: (data, sink) {},
    ));
  }
}
