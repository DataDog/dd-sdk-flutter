// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

export 'intake_platform_web.dart'
    if (dart.library.io) 'intake_platform_native.dart';
