// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';

/// Standard logging setup for a `bin/*.dart` entrypoint -- warnings and
/// above go to stderr (so CI surfaces them even when stdout is otherwise
/// captured/discarded), everything else to stdout.
void configureCliLogging({Level level = Level.FINE}) {
  Logger.root.level = level;
  Logger.root.onRecord.listen((record) {
    if (record.level >= Level.WARNING) {
      stderr.writeln(record.message);
    } else {
      print(record.message);
    }
  });
}
