// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDdRum extends Mock implements DatadogRum {}

Widget _testWidgetBuilder(Widget? child) {
  return SizedBox.square(
    dimension: 5,
    child: Container(color: Colors.white, child: child),
  );
}

class _DescriptiveWidget extends StatelessWidget {
  final Widget? child;

  const _DescriptiveWidget({this.child});

  @override
  Widget build(BuildContext context) {
    return _testWidgetBuilder(child);
  }
}

class _VagueWidget extends StatelessWidget {
  final Widget? child;

  const _VagueWidget({this.child});

  @override
  Widget build(BuildContext context) {
    return _testWidgetBuilder(child);
  }
}

Widget _buildSimpleApp(DatadogRum rum, Widget innerWidget) {
  return RumUserActionDetector(
    rum: rum,
    customGestureDetector: (widget) {
      if (widget is _DescriptiveWidget) {
        return const RumGestureDetectorInfo(
          'DescriptiveWidget',
          searchForText: false,
          searchForBetter: false,
        );
      } else if (widget is _VagueWidget) {
        return const RumGestureDetectorInfo(
          'VagueWidget',
          searchForBetter: true,
          searchForText: true,
        );
      }
      return null;
    },
    child: MaterialApp(
      color: Colors.blueAccent,
      home: Scaffold(
        appBar: AppBar(title: const Text('App Bar Title'), actions: const []),
        body: Column(children: [const Text('This is Text'), innerWidget]),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(RumActionType.custom);
  });

  testWidgets('tap button reports tap to RUM', (tester) async {
    final mockRum = MockDdRum();

    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        ElevatedButton(onPressed: () {}, child: const Text('This is a button')),
      ),
    );

    final button = find.byType(ElevatedButton);
    await tester.tap(button);

    verify(() => mockRum.addAction(RumActionType.tap, any()));
  });

  testWidgets('tap elevated button reports button text to RUM', (tester) async {
    final mockRum = MockDdRum();

    final buttonText = randomString();
    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        ElevatedButton(onPressed: () {}, child: Text(buttonText)),
      ),
    );

    final button = find.byType(ElevatedButton);
    await tester.tap(button);

    verify(() => mockRum.addAction(RumActionType.tap, 'Button($buttonText)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap text button reports button text to RUM', (tester) async {
    final mockRum = MockDdRum();

    final buttonText = randomString();
    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        TextButton(onPressed: () {}, child: Text(buttonText)),
      ),
    );

    final button = find.byType(TextButton);
    await tester.tap(button);

    verify(() => mockRum.addAction(RumActionType.tap, 'Button($buttonText)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap outlined button reports button text to RUM', (tester) async {
    final mockRum = MockDdRum();

    final buttonText = randomString();
    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        OutlinedButton(onPressed: () {}, child: Text(buttonText)),
      ),
    );

    final button = find.byType(OutlinedButton);
    await tester.tap(button);

    verify(() => mockRum.addAction(RumActionType.tap, 'Button($buttonText)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap text does not report tap to RUM', (tester) async {
    final mockRum = MockDdRum();

    final buttonText = randomString();
    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        ElevatedButton(onPressed: () {}, child: Text(buttonText)),
      ),
    );

    final text = find.byType(Text).first;
    await tester.tap(text);

    verifyNever(() => mockRum.addAction(any(), any()));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap gesture detector with text reports unknown description', (
    tester,
  ) async {
    final mockRum = MockDdRum();

    final buttonText = randomString();
    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        GestureDetector(onTap: () {}, child: Text(buttonText)),
      ),
    );

    final text = find.byType(GestureDetector);
    await tester.tap(text);

    verify(
      () => mockRum.addAction(RumActionType.tap, 'GestureDetector(unknown)'),
    );
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap gesture detector with annotation reports description', (
    tester,
  ) async {
    final mockRum = MockDdRum();

    final annotation = randomString();
    final buttonText = randomString();
    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        RumUserActionAnnotation(
          description: annotation,
          child: GestureDetector(onTap: () {}, child: Text(buttonText)),
        ),
      ),
    );

    final text = find.byType(GestureDetector);
    await tester.tap(text);

    verify(
      () =>
          mockRum.addAction(RumActionType.tap, 'GestureDetector($annotation)'),
    );
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('nested tap gesture detector uses lowest in tree', (
    tester,
  ) async {
    final mockRum = MockDdRum();

    final firstAnnotation = randomString();
    final firstButtonText = randomString();
    final secondButtonText = randomString();
    final secondAnnotation = randomString();

    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        RumUserActionAnnotation(
          description: firstAnnotation,
          child: GestureDetector(
            onTap: () {},
            child: Column(
              children: [
                Text(firstButtonText),
                RumUserActionAnnotation(
                  description: secondAnnotation,
                  child: GestureDetector(
                    onTap: () {},
                    child: Text(secondButtonText),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final text = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == secondButtonText,
    );
    await tester.tap(text);

    verify(
      () => mockRum.addAction(
        RumActionType.tap,
        'GestureDetector($secondAnnotation)',
      ),
    );
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets(
    'nested GestureDetector inside InkWell uses inner GestureDetector',
    (tester) async {
      final mockRum = MockDdRum();

      final parentAnnotation = randomString();
      final childAnnotation = randomString();
      final childText = randomString();

      await tester.pumpWidget(
        _buildSimpleApp(
          mockRum,
          RumUserActionAnnotation(
            description: parentAnnotation,
            child: InkWell(
              onTap: () {},
              child: Column(
                children: [
                  const Text('Parent text'),
                  RumUserActionAnnotation(
                    description: childAnnotation,
                    child: GestureDetector(
                      onTap: () {},
                      child: Text(childText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final text = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == childText,
      );
      await tester.tap(text);

      verify(
        () => mockRum.addAction(
          RumActionType.tap,
          'GestureDetector($childAnnotation)',
        ),
      );
      verifyNoMoreInteractions(mockRum);
    },
  );

  testWidgets(
    'nested GestureDetector inside InkWell without annotation uses InkWell',
    (tester) async {
      // When a GestureDetector is nested inside InkWell but has NO annotation,
      // the InkWell should take precedence (the GestureDetector is likely
      // internal or unintentional).
      final mockRum = MockDdRum();

      final parentAnnotation = randomString();
      final childText = randomString();

      await tester.pumpWidget(
        _buildSimpleApp(
          mockRum,
          RumUserActionAnnotation(
            description: parentAnnotation,
            child: InkWell(
              onTap: () {},
              child: Column(
                children: [
                  const Text('Parent text'),
                  // No RumUserActionAnnotation wrapping the GestureDetector
                  GestureDetector(onTap: () {}, child: Text(childText)),
                ],
              ),
            ),
          ),
        ),
      );

      final text = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == childText,
      );
      await tester.tap(text);

      // Should report InkWell since the nested GestureDetector has no annotation
      verify(
        () =>
            mockRum.addAction(RumActionType.tap, 'InkWell($parentAnnotation)'),
      );
      verifyNoMoreInteractions(mockRum);
    },
  );

  testWidgets(
    'nested GestureDetector inside InkWell reports correct attributes',
    (tester) async {
      // Verify that attributes from the inner annotation are correctly reported
      final mockRum = MockDdRum();

      final parentAnnotation = randomString();
      final childAnnotation = randomString();
      final childText = randomString();
      final childAttributes = {'placement': 'child', 'test_id': 12345};

      await tester.pumpWidget(
        _buildSimpleApp(
          mockRum,
          RumUserActionAnnotation(
            description: parentAnnotation,
            attributes: {'placement': 'parent'},
            child: InkWell(
              onTap: () {},
              child: Column(
                children: [
                  const Text('Parent text'),
                  RumUserActionAnnotation(
                    description: childAnnotation,
                    attributes: childAttributes,
                    child: GestureDetector(
                      onTap: () {},
                      child: Text(childText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final text = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == childText,
      );
      await tester.tap(text);

      verify(
        () => mockRum.addAction(
          RumActionType.tap,
          'GestureDetector($childAnnotation)',
          childAttributes,
        ),
      );
      verifyNoMoreInteractions(mockRum);
    },
  );

  testWidgets('tap button with annotation reports annotation over text', (
    tester,
  ) async {
    final mockRum = MockDdRum();

    final annotation = randomString();
    final buttonText = randomString();
    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        RumUserActionAnnotation(
          description: annotation,
          child: TextButton(onPressed: () {}, child: Text(buttonText)),
        ),
      ),
    );

    final text = find.byType(TextButton);
    await tester.tap(text);

    verify(() => mockRum.addAction(RumActionType.tap, 'Button($annotation)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap disabled button does not report tap', (tester) async {
    final mockRum = MockDdRum();

    final buttonText = randomString();
    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        TextButton(onPressed: null, child: Text(buttonText)),
      ),
    );

    final text = find.byType(TextButton);
    await tester.tap(text);

    verifyNever(() => mockRum.addAction(any(), any()));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap non-tap gesture detector does not report tap', (
    tester,
  ) async {
    final mockRum = MockDdRum();

    final buttonText = randomString();
    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        GestureDetector(onLongPress: () {}, child: Text(buttonText)),
      ),
    );

    final text = find.byType(GestureDetector);
    await tester.tap(text);

    verifyNever(() => mockRum.addAction(any(), any()));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap InkWell reports tap without inner text', (tester) async {
    final mockRum = MockDdRum();

    final buttonText = randomString();
    await tester.pumpWidget(
      _buildSimpleApp(mockRum, InkWell(onTap: () {}, child: Text(buttonText))),
    );

    final text = find.byType(GestureDetector);
    await tester.tap(text);

    verify(() => mockRum.addAction(RumActionType.tap, 'InkWell(unknown)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap IconButton reports tap', (tester) async {
    final mockRum = MockDdRum();

    const icon = Icons.ac_unit;
    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        IconButton(onPressed: () {}, icon: const Icon(icon)),
      ),
    );

    final text = find.byType(GestureDetector);
    await tester.tap(text);

    verify(() => mockRum.addAction(RumActionType.tap, 'IconButton(unknown)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap IconButton reports tap with semantic label if available', (
    tester,
  ) async {
    final mockRum = MockDdRum();

    const icon = Icons.ac_unit;
    final semanticLabel = randomString();
    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        IconButton(
          onPressed: () {},
          icon: Icon(icon, semanticLabel: semanticLabel),
        ),
      ),
    );

    final text = find.byType(GestureDetector);
    await tester.tap(text);

    verify(
      () => mockRum.addAction(RumActionType.tap, 'IconButton($semanticLabel)'),
    );
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap IconButton with tooltip reports tooltip message',
      (tester) async {
    final mockRum = MockDdRum();

    final tooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      IconButton(
        onPressed: () {},
        tooltip: tooltip,
        icon: const Icon(Icons.ac_unit),
      ),
    ));

    final button = find.byType(IconButton);
    await tester.tap(button);

    verify(() => mockRum.addAction(RumActionType.tap, 'IconButton($tooltip)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap IconButton with semantic label and tooltip prefers tooltip',
      (tester) async {
    final mockRum = MockDdRum();

    final semanticLabel = randomString();
    final tooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      IconButton(
        onPressed: () {},
        tooltip: tooltip,
        icon: Icon(
          Icons.ac_unit,
          semanticLabel: semanticLabel,
        ),
      ),
    ));

    final button = find.byType(IconButton);
    await tester.tap(button);

    verify(() => mockRum.addAction(RumActionType.tap, 'IconButton($tooltip)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets(
      'tap IconButton with annotation in subtree prefers annotation over tooltip',
      (tester) async {
    final mockRum = MockDdRum();

    final annotation = randomString();
    final tooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      IconButton(
        onPressed: () {},
        tooltip: tooltip,
        icon: RumUserActionAnnotation(
          description: annotation,
          child: const Icon(Icons.ac_unit),
        ),
      ),
    ));

    final button = find.byType(IconButton);
    await tester.tap(button);

    verify(
        () => mockRum.addAction(RumActionType.tap, 'IconButton($annotation)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets(
      'tap IconButton wrapped in annotation prefers annotation over tooltip',
      (tester) async {
    final mockRum = MockDdRum();

    final annotation = randomString();
    final tooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      RumUserActionAnnotation(
        description: annotation,
        child: IconButton(
          onPressed: () {},
          tooltip: tooltip,
          icon: const Icon(Icons.ac_unit),
        ),
      ),
    ));

    final button = find.byType(IconButton);
    await tester.tap(button);

    verify(
        () => mockRum.addAction(RumActionType.tap, 'IconButton($annotation)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap Material 2 IconButton with tooltip reports tooltip message',
      (tester) async {
    final mockRum = MockDdRum();

    final tooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      Theme(
        data: ThemeData(useMaterial3: false),
        child: IconButton(
          onPressed: () {},
          tooltip: tooltip,
          icon: const Icon(Icons.ac_unit),
        ),
      ),
    ));

    final button = find.byType(IconButton);
    await tester.tap(button);

    verify(() => mockRum.addAction(RumActionType.tap, 'IconButton($tooltip)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap button wrapped in Tooltip uses tooltip message as fallback',
      (tester) async {
    final mockRum = MockDdRum();

    final tooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      Tooltip(
        message: tooltip,
        child: ElevatedButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    ));

    final button = find.byType(ElevatedButton);
    await tester.tap(button);

    verify(() => mockRum.addAction(RumActionType.tap, 'Button($tooltip)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap button with text wrapped in Tooltip prefers button text',
      (tester) async {
    final mockRum = MockDdRum();

    final buttonText = randomString();
    final tooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      Tooltip(
        message: tooltip,
        child: ElevatedButton(
          onPressed: () {},
          child: Text(buttonText),
        ),
      ),
    ));

    final button = find.byType(ElevatedButton);
    await tester.tap(button);

    verify(() => mockRum.addAction(RumActionType.tap, 'Button($buttonText)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets(
      'tap button with annotation wrapped in Tooltip prefers annotation',
      (tester) async {
    final mockRum = MockDdRum();

    final annotation = randomString();
    final tooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      Tooltip(
        message: tooltip,
        child: RumUserActionAnnotation(
          description: annotation,
          child: ElevatedButton(
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
        ),
      ),
    ));

    final button = find.byType(ElevatedButton);
    await tester.tap(button);

    verify(() => mockRum.addAction(RumActionType.tap, 'Button($annotation)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap gesture detector wrapped in Tooltip reports tooltip message',
      (tester) async {
    final mockRum = MockDdRum();

    final tooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: () {},
          child: _testWidgetBuilder(null),
        ),
      ),
    ));

    final detector = find.byType(GestureDetector);
    await tester.tap(detector);

    verify(() =>
        mockRum.addAction(RumActionType.tap, 'GestureDetector($tooltip)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap InkWell does not use tooltip of untapped descendant control',
      (tester) async {
    final mockRum = MockDdRum();

    const tapTarget = Key('emptyRowSpace');
    final tooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      InkWell(
        onTap: () {},
        child: Row(
          children: [
            const SizedBox(key: tapTarget, width: 80, height: 48),
            IconButton(
              onPressed: () {},
              tooltip: tooltip,
              icon: const Icon(Icons.delete),
            ),
          ],
        ),
      ),
    ));

    // Tap the empty part of the row, not the IconButton
    await tester.tap(find.byKey(tapTarget));

    verify(() => mockRum.addAction(RumActionType.tap, 'InkWell(unknown)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap button wrapped in Tooltip with richMessage uses plain text',
      (tester) async {
    final mockRum = MockDdRum();

    final tooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      Tooltip(
        richMessage: TextSpan(text: tooltip),
        child: ElevatedButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    ));

    final button = find.byType(ElevatedButton);
    await tester.tap(button);

    verify(() => mockRum.addAction(RumActionType.tap, 'Button($tooltip)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets(
      'tap IconButton with tooltip wrapped in Tooltip prefers its own tooltip',
      (tester) async {
    final mockRum = MockDdRum();

    final ownTooltip = randomString();
    final outerTooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      Tooltip(
        message: outerTooltip,
        child: IconButton(
          onPressed: () {},
          tooltip: ownTooltip,
          icon: const Icon(Icons.ac_unit),
        ),
      ),
    ));

    final button = find.byType(IconButton);
    await tester.tap(button);

    verify(
        () => mockRum.addAction(RumActionType.tap, 'IconButton($ownTooltip)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap button in nested Tooltips uses nearest enclosing message',
      (tester) async {
    final mockRum = MockDdRum();

    final outerTooltip = randomString();
    final innerTooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      Tooltip(
        message: outerTooltip,
        child: Tooltip(
          message: innerTooltip,
          child: ElevatedButton(
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
        ),
      ),
    ));

    final button = find.byType(ElevatedButton);
    await tester.tap(button);

    verify(() => mockRum.addAction(RumActionType.tap, 'Button($innerTooltip)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets(
      'tap button wrapped in Tooltip with empty message reports unknown',
      (tester) async {
    final mockRum = MockDdRum();

    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      Tooltip(
        message: '',
        child: ElevatedButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    ));

    final button = find.byType(ElevatedButton);
    await tester.tap(button);

    verify(() => mockRum.addAction(RumActionType.tap, 'Button(unknown)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap IconButton with empty tooltip reports unknown',
      (tester) async {
    final mockRum = MockDdRum();

    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      IconButton(
        onPressed: () {},
        tooltip: '',
        icon: const Icon(Icons.ac_unit),
      ),
    ));

    final button = find.byType(IconButton);
    await tester.tap(button);

    verify(() => mockRum.addAction(RumActionType.tap, 'IconButton(unknown)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('Tooltip message applies to all hit branches of its subtree',
      (tester) async {
    final mockRum = MockDdRum();

    final tooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.red),
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    ));

    final detector = find.byType(GestureDetector);
    await tester.tap(detector);

    verify(() =>
        mockRum.addAction(RumActionType.tap, 'GestureDetector($tooltip)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('annotation applies to all hit branches of its subtree',
      (tester) async {
    final mockRum = MockDdRum();

    final annotation = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      RumUserActionAnnotation(
        description: annotation,
        child: SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.red),
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    ));

    final detector = find.byType(GestureDetector);
    await tester.tap(detector);

    verify(() =>
        mockRum.addAction(RumActionType.tap, 'GestureDetector($annotation)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap FloatingActionButton with tooltip reports tooltip message',
      (tester) async {
    final mockRum = MockDdRum();

    final tooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      FloatingActionButton(
        onPressed: () {},
        tooltip: tooltip,
        child: const Icon(Icons.add),
      ),
    ));

    final button = find.byType(FloatingActionButton);
    await tester.tap(button);

    verify(() =>
        mockRum.addAction(RumActionType.tap, 'FloatingActionButton($tooltip)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap FloatingActionButton without tooltip reports unknown',
      (tester) async {
    final mockRum = MockDdRum();

    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    ));

    final button = find.byType(FloatingActionButton);
    await tester.tap(button);

    verify(() =>
        mockRum.addAction(RumActionType.tap, 'FloatingActionButton(unknown)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets(
      'tap extended FloatingActionButton prefers tooltip over label text',
      (tester) async {
    final mockRum = MockDdRum();

    final label = randomString();
    final tooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      FloatingActionButton.extended(
        onPressed: () {},
        tooltip: tooltip,
        label: Text(label),
      ),
    ));

    final button = find.byType(FloatingActionButton);
    await tester.tap(button);

    verify(() =>
        mockRum.addAction(RumActionType.tap, 'FloatingActionButton($tooltip)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap extended FloatingActionButton without tooltip reports label',
      (tester) async {
    final mockRum = MockDdRum();

    final label = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      FloatingActionButton.extended(
        onPressed: () {},
        label: Text(label),
      ),
    ));

    final button = find.byType(FloatingActionButton);
    await tester.tap(button);

    verify(() =>
        mockRum.addAction(RumActionType.tap, 'FloatingActionButton($label)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap disabled FloatingActionButton does not report tap',
      (tester) async {
    final mockRum = MockDdRum();

    final tooltip = randomString();
    await tester.pumpWidget(_buildSimpleApp(
      mockRum,
      FloatingActionButton(
        onPressed: null,
        tooltip: tooltip,
        child: const Icon(Icons.add),
      ),
    ));

    final button = find.byType(FloatingActionButton);
    await tester.tap(button);

    verifyNever(() => mockRum.addAction(any(), any()));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap Radio reports tap with value', (tester) async {
    final mockRum = MockDdRum();

    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        Radio(groupValue: 0, onChanged: (value) {}, value: 1),
      ),
    );

    final text = find.byType(Radio<int>);
    await tester.tap(text);

    verify(() => mockRum.addAction(RumActionType.tap, 'Radio(1)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap Radio reports tap with Tree annotation', (tester) async {
    final mockRum = MockDdRum();

    final annotation = randomString();
    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        RumUserActionAnnotation(
          description: annotation,
          child: Radio(groupValue: 0, onChanged: (value) {}, value: 1),
        ),
      ),
    );

    final text = find.byType(Radio<int>);
    await tester.tap(text);

    verify(() => mockRum.addAction(RumActionType.tap, 'Radio($annotation)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap Switch reports tap with Tree annotation', (tester) async {
    final mockRum = MockDdRum();

    final annotation = randomString();
    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        RumUserActionAnnotation(
          description: annotation,
          child: Switch(value: false, onChanged: (value) {}),
        ),
      ),
    );

    final text = find.byType(Switch);
    await tester.tap(text);

    verify(() => mockRum.addAction(RumActionType.tap, 'Switch($annotation)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap BottomNavigationBar reports tap', (tester) async {
    final mockRum = MockDdRum();

    final app = RumUserActionDetector(
      rum: mockRum,
      child: MaterialApp(
        home: Scaffold(
          body: const Center(child: Text('Test')),
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                icon: Icon(Icons.business),
                label: 'Business',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.school),
                label: 'School',
              ),
            ],
            currentIndex: 0,
            onTap: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(app);

    final navItem = find.byIcon(Icons.business).first;
    await tester.tap(navItem);

    verify(
      () => mockRum.addAction(
        RumActionType.tap,
        'BottomNavigationBarItem(Business)',
      ),
    );
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap BottomNavigationBar reports child annotation', (
    tester,
  ) async {
    final mockRum = MockDdRum();

    final app = RumUserActionDetector(
      rum: mockRum,
      child: MaterialApp(
        home: Scaffold(
          body: const Center(child: Text('Test')),
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                icon: RumUserActionAnnotation(
                  description: 'Custom Annotation',
                  attributes: {'custom_attribute': 12345},
                  child: Icon(Icons.business),
                ),
                label: 'Business',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.school),
                label: 'School',
              ),
            ],
            currentIndex: 0,
            onTap: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(app);

    final navItem = find.byIcon(Icons.business).first;
    await tester.tap(navItem);

    verify(
      () => mockRum.addAction(
        RumActionType.tap,
        'BottomNavigationBarItem(Custom Annotation)',
        {'custom_attribute': 12345},
      ),
    );
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap TabBar reports tap', (tester) async {
    final mockRum = MockDdRum();

    final app = RumUserActionDetector(
      rum: mockRum,
      child: DefaultTabController(
        initialIndex: 0,
        length: 3,
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Test'),
              bottom: const TabBar(
                tabs: [
                  Tab(
                    icon: Icon(Icons.cloud_outlined, semanticLabel: 'cloudy'),
                  ),
                  Tab(
                    icon: Icon(
                      Icons.beach_access_sharp,
                      semanticLabel: 'rainy',
                    ),
                  ),
                  Tab(
                    icon: Icon(
                      Icons.brightness_5_sharp,
                      semanticLabel: 'sunny',
                    ),
                  ),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                Center(child: Text('Test 1')),
                Center(child: Text('Test 2')),
                Center(child: Text('Test 3')),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app);

    final navItem = find.byIcon(Icons.beach_access_sharp).first;
    await tester.tap(navItem);

    verify(() => mockRum.addAction(RumActionType.tap, 'Tab(rainy)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap TabBar reports tap with text over icon semantics', (
    tester,
  ) async {
    final mockRum = MockDdRum();

    final app = RumUserActionDetector(
      rum: mockRum,
      child: DefaultTabController(
        initialIndex: 0,
        length: 3,
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Test'),
              bottom: const TabBar(
                tabs: [
                  Tab(
                    icon: Icon(Icons.cloud_outlined, semanticLabel: 'cloudy'),
                  ),
                  Tab(
                    icon: Icon(
                      Icons.beach_access_sharp,
                      semanticLabel: 'rainy',
                    ),
                    text: 'Rainy Days',
                  ),
                  Tab(
                    icon: Icon(
                      Icons.brightness_5_sharp,
                      semanticLabel: 'sunny',
                    ),
                  ),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                Center(child: Text('Test 1')),
                Center(child: Text('Test 2')),
                Center(child: Text('Test 3')),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app);

    final navItem = find.byIcon(Icons.beach_access_sharp).first;
    await tester.tap(navItem);

    verify(() => mockRum.addAction(RumActionType.tap, 'Tab(Rainy Days)'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('tap gesture detector with annotation reports attributes', (
    tester,
  ) async {
    final mockRum = MockDdRum();

    final annotation = randomString();
    final buttonText = randomString();
    final attributes = {'test_key': randomString()};
    await tester.pumpWidget(
      _buildSimpleApp(
        mockRum,
        RumUserActionAnnotation(
          description: annotation,
          attributes: attributes,
          child: GestureDetector(onTap: () {}, child: Text(buttonText)),
        ),
      ),
    );

    final text = find.byType(GestureDetector);
    await tester.tap(text);

    verify(() => mockRum.addAction(RumActionType.tap, any(), attributes));
    verifyNoMoreInteractions(mockRum);
  });

  group('tap custom widget', () {
    testWidgets('reports tap to RUM with unknown annotation by default', (
      tester,
    ) async {
      final mockRum = MockDdRum();

      await tester.pumpWidget(
        _buildSimpleApp(mockRum, const _DescriptiveWidget()),
      );

      final button = find.byType(_DescriptiveWidget);
      await tester.tap(button);

      verify(
        () =>
            mockRum.addAction(RumActionType.tap, 'DescriptiveWidget(unknown)'),
      );
    });

    testWidgets('reports tap to RUM and search for better widget', (
      tester,
    ) async {
      final mockRum = MockDdRum();

      final annotation = randomString();
      await tester.pumpWidget(
        _buildSimpleApp(
          mockRum,
          _VagueWidget(
            child: ElevatedButton(onPressed: () {}, child: Text(annotation)),
          ),
        ),
      );

      final button = find.byType(_VagueWidget);
      await tester.tap(button);

      verify(() => mockRum.addAction(RumActionType.tap, 'Button($annotation)'));
    });

    testWidgets('reports tap to RUM and search for text', (tester) async {
      final mockRum = MockDdRum();

      final annotation = randomString();
      await tester.pumpWidget(
        _buildSimpleApp(mockRum, _VagueWidget(child: Text(annotation))),
      );

      final button = find.byType(_VagueWidget);
      await tester.tap(button);

      verify(
        () => mockRum.addAction(RumActionType.tap, 'VagueWidget($annotation)'),
      );
    });

    testWidgets('reports tap to RUM '
        'and do not search for text '
        'and do not search for better widget', (tester) async {
      final mockRum = MockDdRum();

      final annotation = randomString();
      await tester.pumpWidget(
        _buildSimpleApp(
          mockRum,
          _DescriptiveWidget(
            child: ElevatedButton(onPressed: () {}, child: Text(annotation)),
          ),
        ),
      );

      final button = find.byType(_DescriptiveWidget);
      await tester.tap(button);

      verify(
        () =>
            mockRum.addAction(RumActionType.tap, 'DescriptiveWidget(unknown)'),
      );
    });

    testWidgets('with annotation reports description', (tester) async {
      final mockRum = MockDdRum();

      final annotation = randomString();
      await tester.pumpWidget(
        _buildSimpleApp(
          mockRum,
          RumUserActionAnnotation(
            description: annotation,
            child: const _DescriptiveWidget(),
          ),
        ),
      );

      final text = find.byType(_DescriptiveWidget);
      await tester.tap(text);

      verify(
        () => mockRum.addAction(
          RumActionType.tap,
          'DescriptiveWidget($annotation)',
        ),
      );
      verifyNoMoreInteractions(mockRum);
    });

    testWidgets('with annotation in subtree reports description', (
      tester,
    ) async {
      final mockRum = MockDdRum();

      final annotation = randomString();
      final attributes = {'test_key': randomString()};
      await tester.pumpWidget(
        _buildSimpleApp(
          mockRum,
          _VagueWidget(
            child: RumUserActionAnnotation(
              description: annotation,
              attributes: attributes,
              child: Semantics(child: const SizedBox.shrink()),
            ),
          ),
        ),
      );

      final text = find.byType(_VagueWidget);
      await tester.tap(text);

      verify(
        () => mockRum.addAction(
          RumActionType.tap,
          'VagueWidget($annotation)',
          attributes,
        ),
      );
      verifyNoMoreInteractions(mockRum);
    });
  });
}
