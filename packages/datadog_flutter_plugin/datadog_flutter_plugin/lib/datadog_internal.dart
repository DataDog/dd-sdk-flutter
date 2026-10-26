// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// NB: This import is meant to be used by Datadog for implementation of
// extension packages, and is not meant for public use. Anything exposed by this
// file has the potential to change without notice.

import 'package:datadog_flutter_plugin_platform_interface/datadog_flutter_plugin_platform_interface.dart';
import 'src/rum/ddrum.dart';

export 'package:datadog_flutter_plugin_platform_interface/datadog_internal.dart';
export 'src/datadog_sdk.dart';
export 'src/helpers.dart';
export 'src/sampler.dart';
export 'src/tracing/baggage_helpers.dart';
export 'src/tracing/tracing_headers.dart';
export 'src/version.dart';

extension DatadogRumInternal on DatadogRum {
  TraceContextInjection get contextInjectionSetting => traceContextInjection;
}
