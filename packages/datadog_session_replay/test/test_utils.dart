// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// Because `Color` is defined in `dart:ui`, it can't be imported into the test library
// when running integration tests on Web. When / if we support SR on web, we'll need to look
// into a way to have the Color class work in the test test package.
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

Random _random = Random();

Color randomColor({bool withRandomAlpha = false}) {
  int randomColorComponent() {
    return _random.nextInt(255);
  }

  return Color.fromARGB(
    withRandomAlpha ? randomColorComponent() : 255,
    randomColorComponent(),
    randomColorComponent(),
    randomColorComponent(),
  );
}

// Copied from Flutter's test repo:
// https://codebrowser.dev/flutter/flutter/packages/flutter/test/painting/image_test_utils.dart.html
class TestImageProvider extends ImageProvider<TestImageProvider> {
  TestImageProvider(this.testImage);

  final ui.Image testImage;

  final Completer<ImageInfo> _completer = Completer<ImageInfo>.sync();
  ImageConfiguration? configuration;
  int loadCallCount = 0;

  @override
  Future<TestImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<TestImageProvider>(this);
  }

  @override
  void resolveStreamForKey(
    ImageConfiguration config,
    ImageStream stream,
    TestImageProvider key,
    ImageErrorListener handleError,
  ) {
    configuration = config;
    super.resolveStreamForKey(config, stream, key, handleError);
  }

  @override
  ImageStreamCompleter loadBuffer(
    TestImageProvider key,
    // ignore: deprecated_member_use
    DecoderBufferCallback decode,
  ) {
    throw UnsupportedError('Use ImageProvider.loadImage instead.');
  }

  @override
  ImageStreamCompleter loadImage(
    TestImageProvider key,
    ImageDecoderCallback decode,
  ) {
    loadCallCount += 1;
    return OneFrameImageStreamCompleter(_completer.future);
  }

  ImageInfo complete() {
    final ImageInfo imageInfo = ImageInfo(image: testImage);
    _completer.complete(imageInfo);
    return imageInfo;
  }

  @override
  String toString() => '${describeIdentity(this)}()';
}

/// A test-friendly subclass of [ExactAssetImage] that provides a pre-built
/// [ui.Image] instead of loading from an asset bundle.
class TestExactAssetImage extends ExactAssetImage {
  final ui.Image _testImage;
  final Completer<ImageInfo> _completer = Completer<ImageInfo>.sync();

  TestExactAssetImage(this._testImage) : super('test_asset.png', scale: 2.0);

  @override
  Future<AssetBundleImageKey> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AssetBundleImageKey>(
      AssetBundleImageKey(
        bundle: _DummyAssetBundle(),
        name: 'test_asset.png',
        scale: 2.0,
      ),
    );
  }

  @override
  ImageStreamCompleter loadImage(
    AssetBundleImageKey key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_completer.future);
  }

  void complete() {
    _completer.complete(ImageInfo(image: _testImage));
  }
}

class _DummyAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw UnsupportedError('DummyAssetBundle.load should not be called');
}
