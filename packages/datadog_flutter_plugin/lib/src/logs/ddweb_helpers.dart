// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

@JS()
library ddweb_helpers;

import 'package:js/js.dart';

@JS('Error')
@staticInterop
class JSError {
  external factory JSError();
}

extension JSErrorExtension on JSError {
  external String? stack;
  external String? message;
  external String? name;
}
