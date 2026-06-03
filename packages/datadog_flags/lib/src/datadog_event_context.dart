// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'datadog_context.dart';

Map<String, Object?>? rumContextFor(DatadogFlagsContext context) {
  final applicationId = context.applicationId;
  if (applicationId == null) {
    return null;
  }

  return {
    'application': {'id': applicationId},
    'view': null,
  };
}

Map<String, Object?>? ddContextFor(DatadogFlagsContext context) {
  final ddContext = removeNullValues({
    'service': context.service,
    'rum': rumContextFor(context),
  });
  return ddContext.isEmpty ? null : ddContext;
}
