// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:ci_helpers/swift_package_manager.dart';

// Exits non-zero unless Flutter's Swift Package Manager support is enabled.
Future<void> main() => requireSwiftPackageManager();
