// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:io';

import 'package:datadog_sdk/src/rum/ddrum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RumResourceType parses simple mimeTypes from ContentType', () {
    final image = ContentType.parse('image/png');
    expect(resourceTypeFromContentType(image), RumResourceType.image);

    final video = ContentType.parse('video/mp4');
    expect(resourceTypeFromContentType(video), RumResourceType.media);

    final audio = ContentType.parse('audio/ogg');
    expect(resourceTypeFromContentType(audio), RumResourceType.media);

    final appJavascript = ContentType.parse('application/javascript');
    expect(resourceTypeFromContentType(appJavascript), RumResourceType.js);

    final textJavascript = ContentType.parse('text/javascript');
    expect(resourceTypeFromContentType(textJavascript), RumResourceType.js);

    final font = ContentType.parse('font/collection');
    expect(resourceTypeFromContentType(font), RumResourceType.font);

    final css = ContentType.parse('text/css');
    expect(resourceTypeFromContentType(css), RumResourceType.css);

    final other = ContentType.parse('application/octet-stream');
    expect(resourceTypeFromContentType(other), RumResourceType.native);
  });
}
