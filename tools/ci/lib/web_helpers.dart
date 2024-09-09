// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;

const chromeForTestingUrl =
    'https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json';
Future<void> downloadChromeAndDriver() async {
  print("Getting list of latest chome versions....");
  final platform = _getPlatform();

  final chromeVersionsResponse = await http.get(Uri.parse(chromeForTestingUrl));
  if (!chromeVersionsResponse.ok) {
    print(
        "❌ Failed getting chrome for testing info. Response was: $chromeVersionsResponse");
    return;
  }

  final resultStirng = chromeVersionsResponse.body;
  final chrome = jsonDecode(resultStirng);

  final stableDownloads = chrome['channels']['Stable']['downloads'];
  final chromeDownload = (stableDownloads['chrome'] as List)
      .firstWhereOrNull((e) => e['platform'] == platform);
  if (chromeDownload == null) {
    print("❌ Could not find Chrome download matching platform $platform");
    return;
  }
  final chromeDriverDownload = (stableDownloads['chromedriver'] as List)
      .firstWhereOrNull((e) => e['platform'] == platform);
  if (chromeDriverDownload == null) {
    print("❌ Could not find Chromedriver download matching platform $platform");
    return;
  }

  final tempDr = Directory('.tmp');
  await tempDr.create();

  print('⬇️ Downloading chrome to .tmp/chrome.zip');
  await _getUrlTo(Uri.parse(chromeDownload['url']), '.tmp/chrome.zip');
  print('\n✅ Done.');

  print('⬇️ Downloading chromedriver to .tmp/chromedriver.zip');
  await _getUrlTo(
      Uri.parse(chromeDriverDownload['url']), '.tmp/chromedriver.zip');
  print('\n✅ Done.');
}

Future<void> _getUrlTo(Uri uri, String toPath) async {
  var contentLength = 0;
  var bytesRecieved = 0;

  final client = HttpClient();
  final chromeFile = File(toPath);
  final chromeFileSink = chromeFile.openWrite();
  final chromeRequest = await client.getUrl(uri);
  final chromeResponse = await chromeRequest.close();
  contentLength = chromeResponse.contentLength;

  try {
    await chromeResponse.listen((event) {
      chromeFileSink.add(event);
      bytesRecieved += event.length;

      stdout.write(' --- $bytesRecieved / $contentLength\r');
    }).asFuture();
  } finally {
    chromeFileSink.close();
  }
}

String? _getPlatform() {
  if (Platform.isMacOS) {
    // Datadog only uses arm macs at this point, so just return that.
    return 'mac-arm64';
  } else if (Platform.isWindows) {
    return 'win64';
  } else if (Platform.isLinux) {
    return 'linux64';
  }

  return null;
}

extension ReponseHelper on http.Response {
  bool get ok {
    return statusCode >= 200 && statusCode < 300;
  }
}
