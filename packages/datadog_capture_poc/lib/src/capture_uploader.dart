// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'models/wireframe_payload.dart';

const Uuid uuid = Uuid();

class CaptureUploader {
  final Uri wireframeEndpoint;
  final Uri imagesEndpoint;
  final String session;

  CaptureUploader(String serverUrl)
      : wireframeEndpoint = Uri.parse('$serverUrl/mixed/post-wireframe'),
        imagesEndpoint = Uri.parse('$serverUrl/mixed/post-image'),
        session = uuid.v4();

  Future<void> uploadImages(List<Wireframe> wireframes) async {
    final images = wireframes.where((e) => e.imageCapture != null).map((e) {
      return e.imageCapture!;
    });
    for (final image in images) {
      final uri = imagesEndpoint.replace(queryParameters: {
        'session-id': session,
        'image-tag': image.id,
      });
      var imageData =
          await image.capture.toByteData(format: ImageByteFormat.png);
      http.post(uri, body: imageData!.buffer.asInt8List());
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
