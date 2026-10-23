// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';

DatadogFlagsConfig? flagsExampleConfiguration({
  required DatadogSite site,
  required String clientToken,
  required String env,
  String? applicationId,
}) {
  final flagsSite = datadogFlagsSiteFor(site);
  if (flagsSite == null || clientToken.isEmpty) return null;
  return DatadogFlagsConfig(
    clientToken: clientToken,
    env: env,
    site: flagsSite,
    applicationId: applicationId,
  );
}
