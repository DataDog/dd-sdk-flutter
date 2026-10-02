// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:releaser/flags_version.dart';

void main() {
  Logger.root.onRecord.listen((record) => stderr.writeln(record.message));
  final packageRoot = Directory.fromUri(
    Platform.script.resolve('../../../packages/datadog_flags/'),
  ).path;
  if (!validateFlagsVersion(packageRoot, Logger('FlagsVersion'))) exitCode = 1;
}
