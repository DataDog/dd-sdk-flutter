// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// NB: This import is meant to be used by Datadog for implementation of
// extension packages, and is not meant for public use. Anything exposed by this
// file has the potential to change without notice.

export 'src/attributes.dart';
export 'src/datadog_noop_platform.dart';
export 'src/datadog_sdk_platform_interface.dart';
export 'src/first_party_host.dart';
export 'src/helpers.dart';
export 'src/logs/ddlogs_noop_platform.dart';
export 'src/logs/ddlogs_platform_interface.dart';
export 'src/logs/log_mapper_proxy.dart';
export 'src/rum/ddrum_noop_platform.dart';
export 'src/rum/ddrum_platform_interface.dart';
export 'src/rum/rum_mapper_proxy.dart';
export 'src/internal_logger.dart';
export 'src/rum/attributes.dart';
export 'src/time_provider.dart';
export 'src/tracing/tracing_headers.dart';

// Because resource tracking is in a separate package, but web needs resource
// initialization during initialization, we put the configuration value in
// additionalConfig under this key.
const String trackResourcesConfigKey = '_dd.track_web_resources';
