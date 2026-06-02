// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'src/flags_client.dart';
import 'src/flags_context.dart';

export 'src/datadog_flags.dart';
export 'src/datadog_context.dart';
export 'src/flags_client.dart';
export 'src/flags_configuration.dart';
export 'src/flags_context.dart';
export 'src/flags_details.dart';
export 'src/flags_error.dart';
export 'src/flags_store.dart';

typedef FlagsClient = DatadogFlagsClient;
typedef FlagsEvaluationContext = DatadogFlagsEvaluationContext;
