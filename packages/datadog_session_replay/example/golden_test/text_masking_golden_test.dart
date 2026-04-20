// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_platform_interface.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_goldens/flutter_test_goldens.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'golden_test_helpers.dart';

class MockDatadogSessionReplayPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DatadogSessionReplayPlatform {}

const String renderText =
    '''Call me Ishmael. Some years ago—never mind how long precisely—having little or no money in my purse, and nothing particular to interest me on shore, I thought I would sail about a little and see the watery part of the world. It is a way I have of driving off the spleen and regulating the circulation. Whenever I find myself growing grim about the mouth; whenever it is a damp, drizzly November in my soul; whenever I find myself involuntarily pausing before coffin warehouses, and bringing up the rear of every funeral I meet; and especially whenever my hypos get such an upper hand of me, that it requires a strong moral principle to prevent me from deliberately stepping into the street, and methodically knocking people’s hats off—then, I account it high time tozz get to sea as soon as I can.''';

void main() {
  late SessionReplayRecorder recorder;
  late RUMContext context;
  late MockDatadogSessionReplayPlatform platform;

  setUpAll(() async {
    await TestFonts.loadAppFonts();
  });

  setUp(() {
    recorder = SessionReplayRecorder(
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
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

  testWidgets('global unmasked text', (tester) async {
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
      imagePrivacyLevel: ImagePrivacyLevel.maskNone,
    );
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Mask No Text',
            style: TextStyle(fontFamily: TestFonts.openSans),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            renderText,
            style: TextStyle(fontFamily: TestFonts.openSans),
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('global masked text', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Mask All Text',
            style: TextStyle(fontFamily: TestFonts.openSans),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            renderText,
            style: TextStyle(fontFamily: TestFonts.openSans),
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('override unmasked text', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Mask Specific Text',
            style: TextStyle(fontFamily: TestFonts.openSans),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SessionReplayPrivacy(
            textAndInputPrivacyLevel:
                TextAndInputPrivacyLevel.maskSensitiveInputs,
            child: Text(
              renderText,
              style: TextStyle(fontFamily: TestFonts.openSans),
            ),
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('override masked text', (tester) async {
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
      imagePrivacyLevel: ImagePrivacyLevel.maskNone,
    );
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Unmask Specific Text',
            style: TextStyle(fontFamily: TestFonts.openSans),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SessionReplayPrivacy(
            textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
            child: Text(
              renderText,
              style: TextStyle(fontFamily: TestFonts.openSans),
            ),
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  Widget materialTextFieldsBody() {
    return Column(
      spacing: 12,
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: 'Simple Text Field',
            labelStyle: TextStyle(fontFamily: TestFonts.openSans),
          ),
          style: TextStyle(fontFamily: TestFonts.openSans),
        ),
        TextField(
          decoration: InputDecoration(
            labelText: 'Sensitive Text Field',
            labelStyle: TextStyle(fontFamily: TestFonts.openSans),
          ),
          style: TextStyle(fontFamily: TestFonts.openSans),
          keyboardType: TextInputType.phone,
        ),
        TextField(
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: TextStyle(fontFamily: TestFonts.openSans),
          ),
          style: TextStyle(fontFamily: TestFonts.openSans),
          obscureText: true,
        ),
      ],
    );
  }

  testWidgets('material text fields unmasked content', (tester) async {
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
      imagePrivacyLevel: ImagePrivacyLevel.maskNone,
    );
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Material Fields')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: materialTextFieldsBody(),
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
        for (final field in textField.evaluate()) {
          final finder = find.byWidget(field.widget);
          await tester.tap(finder);
          await tester.pumpAndSettle();
          await tester.enterText(finder, 'testing');
          await tester.pumpAndSettle();
        }
      },
    );
  });

  testWidgets('material text fields mask user input', (tester) async {
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAllInputs,
      imagePrivacyLevel: ImagePrivacyLevel.maskNone,
    );
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Material Fields')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: materialTextFieldsBody(),
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
        for (final field in textField.evaluate()) {
          final finder = find.byWidget(field.widget);
          await tester.tap(finder);
          await tester.pumpAndSettle();
          await tester.enterText(finder, 'testing');
          await tester.pumpAndSettle();
        }
      },
    );
  });

  testWidgets('material text fields mask all', (tester) async {
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
      imagePrivacyLevel: ImagePrivacyLevel.maskNone,
    );
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Material Fields')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: materialTextFieldsBody(),
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
        for (final field in textField.evaluate()) {
          final finder = find.byWidget(field.widget);
          await tester.tap(finder);
          await tester.pumpAndSettle();
          await tester.enterText(finder, 'testing');
          await tester.pumpAndSettle();
        }
      },
    );
  });

  Widget cupertinoTextFieldsBody() {
    return Column(
      spacing: 12,
      children: [
        CupertinoTextField(
          placeholder: 'Simple Text Field',
          placeholderStyle: TextStyle(fontFamily: TestFonts.openSans),
          style: TextStyle(fontFamily: TestFonts.openSans),
        ),
        CupertinoTextField(
          placeholder: 'Sensitive Text Field',
          placeholderStyle: TextStyle(fontFamily: TestFonts.openSans),
          style: TextStyle(fontFamily: TestFonts.openSans),
          keyboardType: TextInputType.phone,
        ),
        CupertinoTextField(
          placeholder: 'Password',
          placeholderStyle: TextStyle(fontFamily: TestFonts.openSans),
          style: TextStyle(fontFamily: TestFonts.openSans),
          obscureText: true,
        ),
      ],
    );
  }

  testWidgets('cupertino text fields unmasked content', (tester) async {
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
      imagePrivacyLevel: ImagePrivacyLevel.maskNone,
    );
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Cupertino Fields')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: cupertinoTextFieldsBody(),
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
        for (final field in textField.evaluate()) {
          final finder = find.byWidget(field.widget);
          await tester.tap(finder);
          await tester.pumpAndSettle();
          await tester.enterText(finder, 'testing');
          await tester.pumpAndSettle();
        }
      },
    );
  });

  testWidgets('cupertino text fields mask user input', (tester) async {
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAllInputs,
      imagePrivacyLevel: ImagePrivacyLevel.maskNone,
    );
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Material Fields')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: cupertinoTextFieldsBody(),
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
        for (final field in textField.evaluate()) {
          final finder = find.byWidget(field.widget);
          await tester.tap(finder);
          await tester.pumpAndSettle();
          await tester.enterText(finder, 'testing');
          await tester.pumpAndSettle();
        }
      },
    );
  });

  testWidgets('cupertino text fields mask all', (tester) async {
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
      imagePrivacyLevel: ImagePrivacyLevel.maskNone,
    );
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Material Fields')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: cupertinoTextFieldsBody(),
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
        for (final field in textField.evaluate()) {
          final finder = find.byWidget(field.widget);
          await tester.tap(finder);
          await tester.pumpAndSettle();
          await tester.enterText(finder, 'testing');
          await tester.pumpAndSettle();
        }
      },
    );
  });
}
