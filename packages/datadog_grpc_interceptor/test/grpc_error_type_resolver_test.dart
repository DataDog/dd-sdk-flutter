// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:datadog_grpc_interceptor/datadog_grpc_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

void main() {
  test('resolves GrpcError', () {
    final error = GrpcError.unavailable('unavailable');

    expect(grpcErrorTypeResolver(error), 'GrpcError');
    expect(grpcErrorTypeResolver(error), error.runtimeType.toString());
  });

  test('does not resolve other errors', () {
    expect(grpcErrorTypeResolver(const SocketException('socket')), isNull);
    expect(grpcErrorTypeResolver(StateError('state')), isNull);
  });
}
