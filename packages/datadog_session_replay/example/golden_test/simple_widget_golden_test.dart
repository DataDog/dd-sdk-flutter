// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_platform_interface.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'golden_test_helpers.dart';
import 'mock_platform.dart';

void main() {
  late SessionReplayRecorder recorder;
  late RUMContext context;
  late MockDatadogSessionReplayPlatform platform;

  setUp(() {
    recorder = SessionReplayRecorder(
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
          touchPrivacyLevel: TouchPrivacyLevel.show,
        ),
    );
    platform = MockDatadogSessionReplayPlatform();
    DatadogSessionReplayPlatform.instance = platform;

    registerFallbackValue(
      CapturedViewAttributes(paintBounds: Rect.zero, scaleX: 1.0, scaleY: 1.0),
    );

    context = RUMContext(
      applicationId: randomString(),
      sessionId: randomString(),
    );
    recorder.updateContext(context);
  });

  tearDown(() {
    platform.clearImages();
  });

  testWidgets('simple containers', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Simple Containers')),
        body: Center(
          child: Column(
            children: [
              Material(
                elevation: 8.0,
                color: Colors.amberAccent,
                surfaceTintColor: Colors.purple,
                child: SizedBox(
                  width: 120,
                  height: 150,
                  child: Center(child: Text('In a Material')),
                ),
              ),
              const SizedBox(width: 0, height: 20),
              ElevatedButton(onPressed: () {}, child: Text('My Button')),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(width: 2),
                  borderRadius: BorderRadius.circular(10.0),
                  color: Colors.blueAccent,
                ),
                width: 150.0,
                height: 150.0,
                alignment: Alignment.center,
                child: Text('In a Container\n'),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(width: 2),
                  color: Colors.pinkAccent,
                  shape: BoxShape.circle,
                ),
                width: 100.0,
                height: 100.0,
              ),
            ],
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('unfocused text fields', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Unfocused Text Fields')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              spacing: 12,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: 'Simple Text Field'),
                ),
                CupertinoTextField(placeholder: 'Cupertino Text Field'),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Bordered Text Field',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Multiline Text Field',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 3,
                  maxLines: 5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('focused material text field', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Focused Material Field')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              spacing: 12,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: 'Simple Text Field'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await snapshotTest(
      tester,
      recorder,
      fixture,
      testActions: () async {
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('material text field with content', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Focused Material Field')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              spacing: 12,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: 'Simple Text Field'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await snapshotTest(
      tester,
      recorder,
      fixture,
      testActions: () async {
        final textField = find.byType(TextField);
        await tester.tap(textField);
        await tester.pumpAndSettle();
        await tester.enterText(textField, 'testing');
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('focused cupertino text field', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Focused cupertino Field')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              spacing: 12,
              children: [
                CupertinoTextField(placeholder: 'Cupertino Text Field'),
              ],
            ),
          ),
        ),
      ),
    );
    await snapshotTest(
      tester,
      recorder,
      fixture,
      testActions: () async {
        await tester.tap(find.byType(CupertinoTextField));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('cupertino text field with content', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Focused Material Field')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              spacing: 12,
              children: [
                CupertinoTextField(placeholder: 'Cupertino Text Field'),
              ],
            ),
          ),
        ),
      ),
    );
    await snapshotTest(
      tester,
      recorder,
      fixture,
      testActions: () async {
        final textField = find.byType(CupertinoTextField);
        await tester.tap(textField);
        await tester.pumpAndSettle();
        await tester.enterText(textField, 'testing');
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('image asset', (tester) async {
    await tester.runAsync(() async {
      await precacheImage(
        AssetImage('assets/dd_logo_v_rgb.png'),
        tester.binding.rootElement!,
      );
    });

    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Images')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              spacing: 12,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Image.asset('assets/dd_logo_v_rgb.png'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });
}
