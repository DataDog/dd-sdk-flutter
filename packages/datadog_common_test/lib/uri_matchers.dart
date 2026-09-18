// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:flutter_test/flutter_test.dart';

// This is purposefully at the top level because it cannot be imported by
// web (because of the depenency on flutter_test). Only test platforms
// that need it should import it.
class HasHost extends CustomMatcher {
  HasHost(Matcher matcher) : super('Uri with host that is', 'host', matcher);

  @override
  Object? featureValueOf(Object? actual) {
    return (actual as Uri).host;
  }
}
