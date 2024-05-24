// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:js_interop';

@JS('Error')
@staticInterop
extension type JSError._(JSObject _) implements JSObject {
  external JSError();
}

extension JSErrorExtension on JSError {
  external String? stack;
  external String? message;
  external String? name;
  // ignore: non_constant_identifier_names
  external String? dd_fingerprint;
}
