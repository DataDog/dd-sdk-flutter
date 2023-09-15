// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDatadogSdkPlatform extends Mock implements DatadogSdkPlatform {}

class MockDatadogSdk extends Mock implements DatadogSdk {}

class MockDdRum extends Mock implements DatadogRum {}

void main() {
  late MockDdRum mockRum;
  late MockDatadogSdkPlatform mockPlatform;
  late MockDatadogSdk mockDatadog;

  setUp(() {
    mockRum = MockDdRum();
    mockPlatform = MockDatadogSdkPlatform();
    mockDatadog = MockDatadogSdk();

    when(() => mockPlatform.updateTelemetryConfiguration(any(), any()))
        .thenAnswer((_) => Future<void>.value());

    when(() => mockDatadog.rum).thenReturn(mockRum);
    when(() => mockDatadog.platform).thenReturn(mockPlatform);
    when(() => mockRum.startView(any(), any(), any()))
        .thenAnswer((_) => Future<void>.value());
    when(() => mockRum.stopView(any(), any()))
        .thenAnswer((_) => Future<void>.value());
  });

  Widget buildFor({required Widget child}) {
    final observer = DatadogNavigationObserver(datadogSdk: mockDatadog);
    return DatadogNavigationObserverProvider(
      navObserver: observer,
      child: MaterialApp(
        navigatorObservers: [observer],
        home: child,
      ),
    );
  }

  Future<void> buildAndNavigateTo({
    required WidgetTester tester,
    String? routeName,
    required WidgetBuilder builder,
  }) async {
    await tester.pumpWidget(buildFor(
      child: SimpleNavigator(
        nextRouteName: routeName,
        builder: builder,
      ),
    ));

    var button = find.text('Navigate');

    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('observer starts root view', (WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(buildFor(child: Container()));

    verify(() => mockRum.startView('/'));
  });

  testWidgets('pushing unnamed route ends current view',
      (WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await buildAndNavigateTo(tester: tester, builder: (_) => Container());

    verify(() => mockRum.startView('/'));
    verify(() => mockRum.stopView('/'));
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('popping unnamed route restarts root view ',
      (WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await buildAndNavigateTo(
        tester: tester, builder: (context) => const SimplePopPage());
    final popButton = find.text('Pop');
    await tester.tap(popButton);
    await tester.pumpAndSettle();

    verifyInOrder([
      () => mockRum.startView('/'),
      () => mockRum.stopView('/'),
      () => mockRum.startView('/'),
    ]);
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('pushing route with name in settings starts new view',
      (WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await buildAndNavigateTo(
      tester: tester,
      routeName: 'NextRoute',
      builder: (_) => Container(),
    );

    verify(() => mockRum.startView('NextRoute'));
  });

  testWidgets('popping from settings named route restarts root view ',
      (WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    void onPopPressed(BuildContext context) {
      Navigator.of(context).pop();
    }

    await buildAndNavigateTo(
      tester: tester,
      routeName: 'NextRoute',
      builder: (context) => Material(
        child: ElevatedButton(
          onPressed: () => onPopPressed(context),
          child: const Text('Pop'),
        ),
      ),
    );
    final popButton = find.text('Pop');
    await tester.tap(popButton);
    await tester.pumpAndSettle();

    verifyInOrder([
      () => mockRum.startView('/'),
      () => mockRum.stopView('/'),
      () => mockRum.startView('NextRoute'),
      () => mockRum.stopView('NextRoute'),
      () => mockRum.startView('/'),
    ]);
    verifyNoMoreInteractions(mockRum);
  });

  Future<void> buildNamedRouteTesterAndNavigate({
    String initialRoute = '/',
    required WidgetTester tester,
    DatadogNavigationObserver? observer,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    observer ??= DatadogNavigationObserver(datadogSdk: mockDatadog);
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [
        observer,
      ],
      initialRoute: initialRoute,
      routes: {
        initialRoute: (context) => const SimpleNamedNavigator(),
        'my_named_route': (context) => Container(),
      },
    ));
    var button = find.text('Navigate');

    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('using named routes starts route name ',
      (WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await buildNamedRouteTesterAndNavigate(
      tester: tester,
    );

    verifyInOrder([
      () => mockRum.startView('/'),
      () => mockRum.stopView('/'),
      () => mockRum.startView('my_named_route'),
    ]);
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('using named route respects initial route name ',
      (WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await buildNamedRouteTesterAndNavigate(
      initialRoute: 'home',
      tester: tester,
    );

    verifyInOrder([
      () => mockRum.startView('home'),
      () => mockRum.stopView('home'),
      () => mockRum.startView('my_named_route'),
    ]);
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('overriding extractor sends extra information',
      (WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    RumViewInfo? infoExtractor(Route<dynamic> route) {
      var name = route.settings.name;
      if (name == 'my_named_route') {
        return RumViewInfo(
          name: name!,
          attributes: {'extra_attribute': 'attribute_value'},
        );
      } else if (name != null) {
        return RumViewInfo(name: name);
      }

      return null;
    }

    var observer = DatadogNavigationObserver(
      datadogSdk: mockDatadog,
      viewInfoExtractor: infoExtractor,
    );
    await buildNamedRouteTesterAndNavigate(tester: tester, observer: observer);

    verifyInOrder([
      () => mockRum.startView('/'),
      () => mockRum.stopView('/'),
      () => mockRum.startView('my_named_route', null, {
            'extra_attribute': 'attribute_value',
          }),
    ]);
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('pushing to route using mixin calls startView',
      (WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await buildAndNavigateTo(
      tester: tester,
      builder: (_) => const MixedDestination(),
    );

    verifyInOrder([
      () => mockRum.startView('/'),
      () => mockRum.stopView('/'),
      () => mockRum.startView('MixedDestination'),
    ]);
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('pop from route using mixin calls stopView',
      (WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await buildAndNavigateTo(
      tester: tester,
      builder: (_) => const MixedDestination(),
    );

    var button = find.text('Pop');
    await tester.tap(button);
    await tester.pumpAndSettle();

    verifyInOrder([
      () => mockRum.startView('/'),
      () => mockRum.stopView('/'),
      () => mockRum.startView('MixedDestination'),
      () => mockRum.stopView('MixedDestination'),
      () => mockRum.startView('/'),
    ]);
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('pushing to route using mixin sends extra info',
      (WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final info = RumViewInfo(
      name: 'MixedDestination',
      attributes: {
        'attribute_key': 'attribute_value',
      },
    );
    await buildAndNavigateTo(
      tester: tester,
      builder: (_) => MixedDestination(info: info),
    );

    verifyInOrder([
      () => mockRum.startView('/'),
      () => mockRum.stopView('/'),
      () => mockRum.startView('MixedDestination', null, {
            'attribute_key': 'attribute_value',
          }),
    ]);
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('pushing to next route with mixin sends stopView',
      (WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await buildAndNavigateTo(
      tester: tester,
      builder: (_) => MixedDestination(
        nextPageBuilder: (_) => const SimplePopPage(),
      ),
    );

    final pushButton = find.text('Push');
    await tester.tap(pushButton);
    await tester.pumpAndSettle();

    verifyInOrder([
      () => mockRum.startView('/'),
      () => mockRum.stopView('/'),
      () => mockRum.startView('MixedDestination'),
      () => mockRum.stopView('MixedDestination'),
    ]);
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('returning to mixin view restarts view',
      (WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await buildAndNavigateTo(
      tester: tester,
      builder: (_) => MixedDestination(
        nextPageBuilder: (_) => const SimplePopPage(),
      ),
    );

    final pushButton = find.text('Push');
    await tester.tap(pushButton);
    await tester.pumpAndSettle();
    final popButton = find.text('Pop');
    await tester.tap(popButton);
    await tester.pumpAndSettle();

    verifyInOrder([
      () => mockRum.startView('/'),
      () => mockRum.stopView('/'),
      () => mockRum.startView('MixedDestination'),
      () => mockRum.stopView('MixedDestination'),
      () => mockRum.startView('MixedDestination'),
    ]);
    verifyNoMoreInteractions(mockRum);
  });

  testWidgets('mixin on named route does not send extra events',
      (WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await buildAndNavigateTo(
      tester: tester,
      routeName: 'second_route',
      builder: (_) => const MixedDestination(),
    );

    verifyInOrder([
      () => mockRum.startView('/'),
      () => mockRum.stopView('/'),
      () => mockRum.startView('second_route')
    ]);
    verifyNoMoreInteractions(mockRum);
  });
}

//////
// Widgets for navigation / testing
//////

// This just navigates to the given Widget constructor with the given
// name on a button press
class SimpleNavigator extends StatelessWidget {
  final WidgetBuilder builder;
  final String? nextRouteName;

  const SimpleNavigator({
    Key? key,
    required this.builder,
    this.nextRouteName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Center(
        child: ElevatedButton(
          onPressed: () => _onNavigate(context),
          child: const Text('Navigate'),
        ),
      ),
    );
  }

  void _onNavigate(BuildContext context) {
    RouteSettings? settings =
        nextRouteName == null ? null : RouteSettings(name: nextRouteName);
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: builder,
      settings: settings,
    ));
  }
}

// This does the same as SimpleNavigator but uses a named route to get to the
// child
class SimpleNamedNavigator extends StatelessWidget {
  const SimpleNamedNavigator({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Center(
        child: ElevatedButton(
          onPressed: () => _onNavigate(context),
          child: const Text('Navigate'),
        ),
      ),
    );
  }

  void _onNavigate(BuildContext context) {
    Navigator.of(context).pushNamed('my_named_route');
  }
}

// This is a destination with the RouteAware mixin applied
// to automatically track push / pop.
class MixedDestination extends StatefulWidget {
  final RumViewInfo? info;
  final WidgetBuilder? nextPageBuilder;

  const MixedDestination({
    Key? key,
    this.info,
    this.nextPageBuilder,
  }) : super(key: key);

  @override
  State<MixedDestination> createState() => _MixedDestinationState();
}

class _MixedDestinationState extends State<MixedDestination>
    with RouteAware, DatadogRouteAwareMixin {
  @override
  RumViewInfo get rumViewInfo {
    return widget.info ?? super.rumViewInfo;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        children: [
          if (widget.nextPageBuilder != null)
            ElevatedButton(onPressed: _onPush, child: const Text('Push')),
          ElevatedButton(
            child: const Text('Pop'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _onPush() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: widget.nextPageBuilder!),
    );
  }
}

// This is a simple page with only a Pop button that calls
// the `Navigator.pop` function
class SimplePopPage extends StatelessWidget {
  const SimplePopPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      child: ElevatedButton(
        onPressed: () => _onPopPressed(context),
        child: const Text('Pop'),
      ),
    );
  }

  void _onPopPressed(BuildContext context) {
    Navigator.of(context).pop();
  }
}
