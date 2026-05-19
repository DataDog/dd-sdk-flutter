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
import 'package:flutter_test_goldens/flutter_test_goldens.dart';
import 'package:mocktail/mocktail.dart';

import 'golden_test_helpers.dart';
import 'mock_platform.dart';

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
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
      ),
      touchPrivacyLevel: TouchPrivacyLevel.show,
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

  testWidgets('unmasked checkboxes', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Unmasked Checkboxes')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Checkbox(value: true, onChanged: (_) {}),
              Checkbox(value: false, onChanged: (_) {}),
              Checkbox(value: null, tristate: true, onChanged: (_) {}),
              Checkbox(value: true, onChanged: null),
              Checkbox(value: false, onChanged: null),
              CupertinoCheckbox(value: true, onChanged: (_) {}),
              CupertinoCheckbox(value: false, onChanged: (_) {}),
              CupertinoCheckbox(value: null, tristate: true, onChanged: (_) {}),
              CupertinoCheckbox(value: true, onChanged: null),
              CupertinoCheckbox(value: false, onChanged: null),
            ],
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('masked checkboxes', (tester) async {
    recorder = SessionReplayRecorder(
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAllInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
      ),
      touchPrivacyLevel: TouchPrivacyLevel.show,
    );
    recorder.updateContext(context);

    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Masked Checkboxes')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Checkbox(value: true, onChanged: (_) {}),
              Checkbox(value: false, onChanged: (_) {}),
              Checkbox(value: null, tristate: true, onChanged: (_) {}),
              CupertinoCheckbox(value: true, onChanged: (_) {}),
              CupertinoCheckbox(value: false, onChanged: (_) {}),
              CupertinoCheckbox(value: null, tristate: true, onChanged: (_) {}),
            ],
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('unmasked radios', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Unmasked Radios')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RadioGroup<int>(
                groupValue: 1,
                onChanged: (_) {},
                child: Radio<int>(value: 1),
              ),
              RadioGroup<int>(
                groupValue: 2,
                onChanged: (_) {},
                child: Radio<int>(value: 1),
              ),
              Radio<int>(value: 1),
              RadioGroup<int>(
                groupValue: 1,
                onChanged: (_) {},
                child: CupertinoRadio<int>(value: 1),
              ),
              RadioGroup<int>(
                groupValue: 2,
                onChanged: (_) {},
                child: CupertinoRadio<int>(value: 1),
              ),
              CupertinoRadio<int>(value: 1),
            ],
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('masked radios', (tester) async {
    recorder = SessionReplayRecorder(
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAllInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
      ),
      touchPrivacyLevel: TouchPrivacyLevel.show,
    );
    recorder.updateContext(context);

    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Masked Radios')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RadioGroup<int>(
                groupValue: 1,
                onChanged: (_) {},
                child: Radio<int>(value: 1),
              ),
              RadioGroup<int>(
                groupValue: 1,
                onChanged: (_) {},
                child: CupertinoRadio<int>(value: 1),
              ),
            ],
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('unmasked switches', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Unmasked Switches')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Switch(value: true, onChanged: (_) {}),
              Switch(value: false, onChanged: (_) {}),
              Switch(value: true, onChanged: null),
              Switch(value: false, onChanged: null),
              CupertinoSwitch(value: true, onChanged: (_) {}),
              CupertinoSwitch(value: false, onChanged: (_) {}),
              CupertinoSwitch(value: true, onChanged: null),
              CupertinoSwitch(value: false, onChanged: null),
            ],
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('masked switches', (tester) async {
    recorder = SessionReplayRecorder(
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAllInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
      ),
      touchPrivacyLevel: TouchPrivacyLevel.show,
    );
    recorder.updateContext(context);

    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Masked Switches')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Switch(value: true, onChanged: (_) {}),
              Switch(value: false, onChanged: (_) {}),
              CupertinoSwitch(value: true, onChanged: (_) {}),
              CupertinoSwitch(value: false, onChanged: (_) {}),
            ],
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('unmasked material sliders', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Unmasked Material Sliders')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // year2023 = true (default M3 round thumb) — min, mid, max.
                Slider(value: 0.0, onChanged: (_) {}),
                Slider(value: 0.5, onChanged: (_) {}),
                Slider(value: 1.0, onChanged: (_) {}),
                // Custom colors.
                Slider(
                  value: 0.5,
                  onChanged: (_) {},
                  activeColor: Colors.green,
                  inactiveColor: Colors.yellow,
                  thumbColor: Colors.red,
                ),
                // With secondary track value.
                Slider(
                  value: 0.3,
                  secondaryTrackValue: 0.7,
                  onChanged: (_) {},
                ),
                // Discrete slider with tick marks.
                Slider(value: 0.4, divisions: 5, onChanged: (_) {}),
                // M3-2024 (year2023 = false) — handle thumb + gap + stop indicator.
                Slider(
                  // ignore: deprecated_member_use
                  year2023: false,
                  value: 0.4,
                  onChanged: (_) {},
                ),
                Slider(
                  // ignore: deprecated_member_use
                  year2023: false,
                  value: 0.4,
                  divisions: 5,
                  onChanged: (_) {},
                ),
                // Disabled.
                Slider(value: 0.5, onChanged: null),
              ],
            ),
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('unmasked cupertino sliders', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Unmasked Cupertino Sliders')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoSlider(value: 0.0, onChanged: (_) {}),
                CupertinoSlider(value: 0.5, onChanged: (_) {}),
                CupertinoSlider(value: 1.0, onChanged: (_) {}),
                CupertinoSlider(
                  value: 0.5,
                  onChanged: (_) {},
                  activeColor: CupertinoColors.systemPurple,
                  thumbColor: CupertinoColors.systemPurple,
                ),
                CupertinoSlider(value: 0.5, onChanged: null),
                CupertinoSlider(value: 0.5, divisions: 5, onChanged: (_) {}),
              ],
            ),
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('masked material sliders', (tester) async {
    recorder = SessionReplayRecorder(
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAllInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
      ),
      touchPrivacyLevel: TouchPrivacyLevel.show,
    );
    recorder.updateContext(context);

    // With maskAllInputs every thumb should be anchored at the track midpoint
    // regardless of the supplied value (0.0, 0.5, 1.0 should all look the same).
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Masked Material Sliders')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // year2023 = true (default M3 round thumb) — min, mid, max.
                Slider(value: 0.0, onChanged: (_) {}),
                Slider(value: 0.5, onChanged: (_) {}),
                Slider(value: 1.0, onChanged: (_) {}),
                // Custom colors.
                Slider(
                  value: 0.5,
                  onChanged: (_) {},
                  activeColor: Colors.green,
                  inactiveColor: Colors.yellow,
                  thumbColor: Colors.red,
                ),
                // With secondary track value.
                Slider(
                  value: 0.3,
                  secondaryTrackValue: 0.7,
                  onChanged: (_) {},
                ),
                // Discrete slider with tick marks.
                Slider(value: 0.4, divisions: 5, onChanged: (_) {}),
                // M3-2024 (year2023 = false) — handle thumb + gap + stop indicator.
                Slider(
                  // ignore: deprecated_member_use
                  year2023: false,
                  value: 0.4,
                  onChanged: (_) {},
                ),
                Slider(
                  // ignore: deprecated_member_use
                  year2023: false,
                  value: 0.4,
                  divisions: 5,
                  onChanged: (_) {},
                ),
                // Disabled.
                Slider(value: 0.5, onChanged: null),
              ],
            ),
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('masked cupertino sliders', (tester) async {
    recorder = SessionReplayRecorder(
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAllInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
      ),
      touchPrivacyLevel: TouchPrivacyLevel.show,
    );
    recorder.updateContext(context);

    // With maskAllInputs every thumb should be anchored at the track midpoint
    // regardless of the supplied value (0.0, 0.5, 1.0 should all look the same).
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Masked Cupertino Sliders')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoSlider(value: 0.0, onChanged: (_) {}),
                CupertinoSlider(value: 0.5, onChanged: (_) {}),
                CupertinoSlider(value: 1.0, onChanged: (_) {}),
                CupertinoSlider(
                  value: 0.5,
                  onChanged: (_) {},
                  activeColor: CupertinoColors.systemPurple,
                  thumbColor: CupertinoColors.systemPurple,
                ),
                CupertinoSlider(value: 0.5, onChanged: null),
                CupertinoSlider(value: 0.5, divisions: 5, onChanged: (_) {}),
              ],
            ),
          ),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });
}
