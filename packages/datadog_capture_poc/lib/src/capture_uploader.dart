// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui
    show Image, ImageByteFormat, PixelFormat, decodeImageFromPixels;

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'models/wireframe_payload.dart';

const Uuid uuid = Uuid();

Future<ui.Image> croppedImage(
    ui.Image image, int sx, int sy, int w, int h) async {
  final rawCrop = Uint8List(w * h * 4);
  var rawData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  var rawDataOffset = rawData!.buffer.asUint8List(sy * image.width * 4);

  for (int y = 0; y < h; ++y) {
    for (int x = 0; x < w; ++x) {
      int srcLoc = (y * image.width * 4) + (x + sx) * 4;
      int destLoc = (y * w * 4) + x * 4;
      rawCrop[destLoc + 0] = rawDataOffset[srcLoc + 0];
      rawCrop[destLoc + 1] = rawDataOffset[srcLoc + 1];
      rawCrop[destLoc + 2] = rawDataOffset[srcLoc + 2];
      rawCrop[destLoc + 3] = rawDataOffset[srcLoc + 3];
    }
  }

  final completer = Completer<ui.Image>();

  ui.decodeImageFromPixels(rawCrop, w, h, ui.PixelFormat.rgba8888,
      (decoded) => completer.complete(decoded));

  return completer.future;
}

class CaptureUploader {
  final Uri wireframeEndpoint;
  final Uri imagesEndpoint;
  final String session;

  CaptureUploader(String serverUrl)
      : wireframeEndpoint = Uri.parse('$serverUrl/mixed/post-wireframe'),
        imagesEndpoint = Uri.parse('$serverUrl/mixed/post-image'),
        session = uuid.v4();

  Future<void> uploadImages(List<Wireframe> wireframes) async {
    final images = wireframes.where((e) => e.imageCapture != null);

    for (final image in images) {
      final uri = imagesEndpoint.replace(queryParameters: {
        'session-id': session,
        'image-tag': image.imageCapture!.id,
      });

      final imageCapture = image.imageCapture!;
      Uint8List? imageData;

      // TODO: Move this out of the uploader, it doesn't belong here
      if (imageCapture.cropRect) {
        // Don't send images outside the bounds of the screen capture.
        if (image.x > 0 &&
            image.x < imageCapture.capture.width &&
            (image.x + image.w) < imageCapture.capture.width &&
            image.y > 0 &&
            image.y < imageCapture.capture.height &&
            (image.y + image.h) < imageCapture.capture.height) {
          final cropped = await croppedImage(
              imageCapture.capture,
              image.x.toInt(),
              image.y.toInt(),
              image.w.toInt(),
              image.h.toInt());
          imageData =
              (await cropped.toByteData(format: ui.ImageByteFormat.png))!
                  .buffer
                  .asUint8List();
        }
      } else {
        imageData = (await imageCapture.capture
                .toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
      }

      if (imageData != null) {
        http.post(uri, body: imageData);
      }
    }
  }

  Future<void> uploadWireframes(List<Wireframe> wireframes) async {
    final uri = wireframeEndpoint.replace(
      queryParameters: {
        'session-id': session,
      },
    );
    final encodedWireframes = wireframes.map((e) => e.toJson()).toList();
    final jsonBody = json.encode({'wireframes': encodedWireframes});
    try {
      var response = await http.post(
        uri,
        body: jsonBody,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        print('Error sending wireframes: ${response.body}');
      }
    } catch (e) {
      print('Error sending wireframes: $e');
    }
  }
}
