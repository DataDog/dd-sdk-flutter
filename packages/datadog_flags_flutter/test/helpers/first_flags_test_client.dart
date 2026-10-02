// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';

DatadogFlutterFlagsClient createFirstFlagsTestClient(
  Future<DatadogFlagsClient> Function() resolve,
) =>
    DatadogFlutterFlagsClient(
      name: 'default',
      resolveDelegate: resolve,
      addRumFeatureFlagEvaluation: null,
    );
