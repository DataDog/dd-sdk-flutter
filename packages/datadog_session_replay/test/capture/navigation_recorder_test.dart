// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// Note: to properly test recorders, we need to supply a full widget tree, as
// Element is too difficult to mock effectively.
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/navigation_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/extensions.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';
import 'simple_test_capture.dart';

void main() {
  late SessionReplayRecorder recorder;
  late RUMContext context;

  setUp(() {
    recorder = SessionReplayRecorder.withCustomRecorders(
      [NavigationRecorder(KeyGenerator())],
      defaultCapturePrivacy: const TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      ),
    );
    context = RUMContext(
      applicationId: randomString(),
      sessionId: randomString(),
    );
    recorder.updateContext(context);
  });

  Widget _materialStack(Widget child) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: ThemeData(),
        child: Material(child: Stack(children: [child])),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TabBar
  // ---------------------------------------------------------------------------

  group('TabBar', () {
    testWidgets('produces one indicator node', (tester) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            DefaultTabController(
              length: 3,
              child: TabBar(
                tabs: const [
                  Tab(text: 'A'),
                  Tab(text: 'B'),
                  Tab(text: 'C'),
                ],
              ),
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      // Only the underline indicator node (no background).
      expect(nodes.length, 1);

      final indicator = nodes[0].buildWireframes().first as SRShapeWireframe;
      expect(indicator.width, greaterThan(0));
      expect(indicator.height, greaterThan(0));
    });

    testWidgets('indicator is positioned in the selected tab column', (
      tester,
    ) async {
      // Capture with selectedIndex=0.
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            DefaultTabController(
              length: 3,
              initialIndex: 0,
              child: TabBar(
                tabs: const [Tab(text: 'A'), Tab(text: 'B'), Tab(text: 'C')],
              ),
            ),
          ),
        ),
      );
      final captureIdx0 = await recorder.performCapture();
      final indicatorX0 =
          (captureIdx0!.viewTreeSnapshot.nodes[0].buildWireframes().first
                  as SRShapeWireframe)
              .x;

      // Capture with selectedIndex=2.
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            DefaultTabController(
              length: 3,
              initialIndex: 2,
              child: TabBar(
                tabs: const [Tab(text: 'A'), Tab(text: 'B'), Tab(text: 'C')],
              ),
            ),
          ),
        ),
      );
      final captureIdx2 = await recorder.performCapture();
      final indicatorX2 =
          (captureIdx2!.viewTreeSnapshot.nodes[0].buildWireframes().first
                  as SRShapeWireframe)
              .x;

      // Indicator shifts right when a later tab is selected.
      expect(indicatorX2, greaterThan(indicatorX0));
    });

    testWidgets('indicator color matches indicatorColor', (tester) async {
      final indicatorColor = randomColor();
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            DefaultTabController(
              length: 2,
              child: TabBar(
                indicatorColor: indicatorColor,
                tabs: const [Tab(text: 'A'), Tab(text: 'B')],
              ),
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      final indicator =
          capture!.viewTreeSnapshot.nodes[0].buildWireframes().first
              as SRShapeWireframe;

      expect(
        indicator.shapeStyle?.backgroundColor,
        indicatorColor.toHexString(),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // BottomNavigationBar (Material 2)
  // ---------------------------------------------------------------------------

  group('BottomNavigationBar', () {
    testWidgets('produces background and highlight nodes', (tester) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            BottomNavigationBar(
              currentIndex: 1,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.star),
                  label: 'Starred',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      // Background + highlight indicator = 2 nodes.
      expect(nodes.length, 2);

      final background = nodes[0].buildWireframes().first as SRShapeWireframe;
      final highlight = nodes[1].buildWireframes().first as SRShapeWireframe;

      // Background spans the full widget width.
      expect(background.width, greaterThan(0));
      // Highlight is narrower than the background.
      expect(highlight.width, lessThan(background.width));
      // Highlight is vertically centred within the bar.
      expect(highlight.y, greaterThanOrEqualTo(background.y));
      expect(
        highlight.y + highlight.height,
        lessThanOrEqualTo(background.y + background.height),
      );
    });

    testWidgets('highlight shifts right when currentIndex increases', (
      tester,
    ) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            BottomNavigationBar(
              currentIndex: 0,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'A'),
                BottomNavigationBarItem(icon: Icon(Icons.star), label: 'B'),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: 'C'),
              ],
            ),
          ),
        ),
      );
      final capture0 = await recorder.performCapture();
      final highlightX0 =
          (capture0!.viewTreeSnapshot.nodes[1].buildWireframes().first
                  as SRShapeWireframe)
              .x;

      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            BottomNavigationBar(
              currentIndex: 2,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'A'),
                BottomNavigationBarItem(icon: Icon(Icons.star), label: 'B'),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: 'C'),
              ],
            ),
          ),
        ),
      );
      final capture2 = await recorder.performCapture();
      final highlightX2 =
          (capture2!.viewTreeSnapshot.nodes[1].buildWireframes().first
                  as SRShapeWireframe)
              .x;

      expect(highlightX2, greaterThan(highlightX0));
    });

    testWidgets('background color matches backgroundColor', (tester) async {
      final bgColor = randomColor();
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            BottomNavigationBar(
              backgroundColor: bgColor,
              currentIndex: 0,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'A'),
                BottomNavigationBarItem(icon: Icon(Icons.star), label: 'B'),
              ],
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      final background =
          capture!.viewTreeSnapshot.nodes[0].buildWireframes().first
              as SRShapeWireframe;

      expect(background.shapeStyle?.backgroundColor, bgColor.toHexString());
    });
  });

  // ---------------------------------------------------------------------------
  // NavigationBar (Material 3)
  // ---------------------------------------------------------------------------

  group('NavigationBar', () {
    testWidgets('produces background and pill indicator nodes', (tester) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            NavigationBar(
              selectedIndex: 1,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.star), label: 'Star'),
                NavigationDestination(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      // Background + pill indicator = 2 nodes.
      expect(nodes.length, 2);

      final background = nodes[0].buildWireframes().first as SRShapeWireframe;
      final pill = nodes[1].buildWireframes().first as SRShapeWireframe;

      expect(background.width, greaterThan(0));
      // Pill is narrower than the bar.
      expect(pill.width, lessThan(background.width));
      // Pill is taller than zero.
      expect(pill.height, greaterThan(0));
    });

    testWidgets('pill shifts right when selectedIndex increases', (
      tester,
    ) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            NavigationBar(
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'A'),
                NavigationDestination(icon: Icon(Icons.star), label: 'B'),
                NavigationDestination(icon: Icon(Icons.person), label: 'C'),
              ],
            ),
          ),
        ),
      );
      final capture0 = await recorder.performCapture();
      final pillX0 =
          (capture0!.viewTreeSnapshot.nodes[1].buildWireframes().first
                  as SRShapeWireframe)
              .x;

      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            NavigationBar(
              selectedIndex: 2,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'A'),
                NavigationDestination(icon: Icon(Icons.star), label: 'B'),
                NavigationDestination(icon: Icon(Icons.person), label: 'C'),
              ],
            ),
          ),
        ),
      );
      final capture2 = await recorder.performCapture();
      final pillX2 =
          (capture2!.viewTreeSnapshot.nodes[1].buildWireframes().first
                  as SRShapeWireframe)
              .x;

      expect(pillX2, greaterThan(pillX0));
    });

    testWidgets('background color matches backgroundColor', (tester) async {
      final bgColor = randomColor();
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            NavigationBar(
              backgroundColor: bgColor,
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'A'),
                NavigationDestination(icon: Icon(Icons.star), label: 'B'),
              ],
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      final background =
          capture!.viewTreeSnapshot.nodes[0].buildWireframes().first
              as SRShapeWireframe;

      expect(background.shapeStyle?.backgroundColor, bgColor.toHexString());
    });
  });

  // ---------------------------------------------------------------------------
  // NavigationRail
  // ---------------------------------------------------------------------------

  group('NavigationRail', () {
    testWidgets('produces background and pill indicator nodes', (tester) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            NavigationRail(
              selectedIndex: 0,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.star),
                  label: Text('Starred'),
                ),
              ],
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      // Background + pill indicator = 2 nodes.
      expect(nodes.length, 2);

      final background = nodes[0].buildWireframes().first as SRShapeWireframe;
      final pill = nodes[1].buildWireframes().first as SRShapeWireframe;

      // Rail has non-zero height and width.
      expect(background.height, greaterThan(0));
      expect(background.width, greaterThan(0));
      // Pill is narrower than the rail.
      expect(pill.width, lessThan(background.width));
    });

    testWidgets('pill shifts down when selectedIndex increases', (
      tester,
    ) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            NavigationRail(
              selectedIndex: 0,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.star),
                  label: Text('Starred'),
                ),
              ],
            ),
          ),
        ),
      );
      final capture0 = await recorder.performCapture();
      final pillY0 =
          (capture0!.viewTreeSnapshot.nodes[1].buildWireframes().first
                  as SRShapeWireframe)
              .y;

      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            NavigationRail(
              selectedIndex: 1,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.star),
                  label: Text('Starred'),
                ),
              ],
            ),
          ),
        ),
      );
      final capture1 = await recorder.performCapture();
      final pillY1 =
          (capture1!.viewTreeSnapshot.nodes[1].buildWireframes().first
                  as SRShapeWireframe)
              .y;

      // Pill moves downward when a lower destination is selected.
      expect(pillY1, greaterThan(pillY0));
    });

    testWidgets('background color matches backgroundColor', (tester) async {
      final bgColor = randomColor();
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            NavigationRail(
              backgroundColor: bgColor,
              selectedIndex: 0,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.star),
                  label: Text('Starred'),
                ),
              ],
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      final background =
          capture!.viewTreeSnapshot.nodes[0].buildWireframes().first
              as SRShapeWireframe;

      expect(background.shapeStyle?.backgroundColor, bgColor.toHexString());
    });
  });
}
