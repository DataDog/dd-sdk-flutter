// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:datadog_session_replay/src/datadog_session_replay_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDatadogSessionReplayPlatform extends Mock
    with
        // ignore: invalid_use_of_visible_for_testing_member
        MockPlatformInterfaceMixin
    implements
        DatadogSessionReplayPlatform {
  Map<String, ImageData> imageCache = {};

  @override
  FutureOr<void> saveImageForProcessing(
    int resourceKey,
    int width,
    int height,
    ByteData byteData,
  ) async {
    final data = ImageData(resourceKey, width, height, byteData);
    imageCache[resourceKey.toString()] = data;
    final completer = Completer();
    ui.decodeImageFromPixels(
      byteData.buffer.asUint8List(),
      width,
      height,
      ui.PixelFormat.rgba8888,
      (image) {
        data.image = image;
        completer.complete();
      },
    );
    return completer.future;
  }

  @override
  String? resourceIdForKey(int resourceKey) {
    return resourceKey.toString();
  }

  void clearImages() {
    for (final imageData in imageCache.values) {
      imageData.image?.dispose();
    }
    imageCache.clear();
  }
}

class ImageData {
  final int key;
  final int width;
  final int height;
  final ByteData data;
  ui.Image? image;

  ImageData(this.key, this.width, this.height, this.data);
}
