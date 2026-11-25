// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:js_interop';

@anonymous
extension type JsUser._(JSObject _) implements JSObject {
  external String get id;
  external String? get email;
  external String? get name;

  external factory JsUser({String id, String? email, String? name});
}

@anonymous
extension type JsAccount._(JSObject _) implements JSObject {
  external String get id;
  external String? get name;

  external factory JsAccount({String id, String? name});
}
