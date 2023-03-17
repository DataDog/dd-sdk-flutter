// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:flutter/material.dart';

import '../../datadog_flutter_plugin.dart';
import '../../datadog_internal.dart';

/// Information about a View that will be passed to [DdRum.startView]
class RumViewInfo {
  /// The name of the view
  final String name;

  /// A path to the view
  final String? path;

  /// Any attributes to be associated with this view
  final Map<String, Object?> attributes;

  RumViewInfo({
    required this.name,
    this.path,
    this.attributes = const {},
  });
}

/// A function that can be used to supply custom information to
/// [DdRum.startView].
///
/// Returning `null` from this function will prevent the call
/// to [DdRum.startView].
///
/// See [DatadogNavigationObserver.viewInfoExtractor].
typedef ViewInfoExtractor = RumViewInfo? Function(Route route);

RumViewInfo? defaultViewInfoExtractor(Route route) {
  if (route is PageRoute) {
    var name = route.settings.name;
    if (name != null) {
      return RumViewInfo(name: name);
    }
  }

  return null;
}

/// This class can be added to a MaterialApp to automatically start and stop RUM
/// views, provided you are using named routes with methods like
/// [Navigator.pushNamed], or supplying route names through [RouteSettings] when
/// using [Navigator.push].
///
/// Alternately, the [DatadogNavigationObserver] can also be used in conjunction
/// with [DatadogNavigationObserverProvider] and [DatadogRouteAwareMixin] to
/// automatically start and stop RUM views on widgets that use the mixin.
///
/// If you want more control over the names and attributes that are sent to RUM,
/// you can supply a [ViewInfoExtractor] function to [viewInfoExtractor]. This
/// function is called with the current Route, and can be used to supply a
/// different name, path, or extra attributes to any route.
class DatadogNavigationObserver extends RouteObserver<ModalRoute<dynamic>>
    with WidgetsBindingObserver {
  final ViewInfoExtractor viewInfoExtractor;
  final DatadogSdk datadogSdk;

  RumViewInfo? _currentView;
  RumViewInfo? _pendingView;

  DatadogNavigationObserver({
    required this.datadogSdk,
    this.viewInfoExtractor = defaultViewInfoExtractor,
  }) {
    ambiguate(WidgetsBinding.instance)?.addObserver(this);
    datadogSdk.updateConfigurationInfo(
        LateConfigurationProperty.trackViewsManually, false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        final pendingView = _pendingView;
        _pendingView = null;
        _startView(pendingView);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_currentView != null) {
          _pendingView = _currentView;
          _stopView(_currentView);
        }
        break;
    }
  }

  void _startView(RumViewInfo? viewInfo) {
    if (ambiguate(WidgetsBinding.instance)?.lifecycleState !=
        AppLifecycleState.resumed) {
      _pendingView = viewInfo;
    } else {
      _currentView = viewInfo;
      if (viewInfo != null) {
        datadogSdk.rum?.startView(viewInfo.name, null, viewInfo.attributes);
      } else {
        _pendingView = viewInfo;
      }
    }
  }

  void _stopView(RumViewInfo? viewInfo) {
    if (viewInfo != null) {
      datadogSdk.rum?.stopView(viewInfo.name);
    }
    _currentView = null;
  }

  void _sendScreenView(Route? newRoute, Route? oldRoute) {
    final oldViewInfo = oldRoute != null ? viewInfoExtractor(oldRoute) : null;
    final newViewInfo = newRoute != null ? viewInfoExtractor(newRoute) : null;

    _stopView(oldViewInfo);
    _startView(newViewInfo);
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    _sendScreenView(route, previousRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    _sendScreenView(newRoute, oldRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);

    // On pop, the "previous" route is now the new route.
    _sendScreenView(previousRoute, route);
  }
}

/// The DatadogRouteAwareMixin can be used to supply names and additional
/// attributes to RUM views as an alternative to supplying a [ViewInfoExtractor]
/// to [DatadogNavigationObserver], supplying a name when creating the route, or
/// using named routes.
///
/// Usage:
///
/// ```
/// class ViewWidget extends StatefulWidget {
///   const ViewWidget({Key? key}) : super(key: key);
///
///   @override
///   _ViewWidgetState createState() => _ViewWidgetState();
/// }
///
/// class _ViewWidgetState extends State<ViewWidget>
///     with RouteAware, DatadogRouteAwareMixin {
///   // ...
/// }
/// ```
///
/// By default, DatadogRouteAwareMixin will use the name of its parent Widget as
/// the name of the route, **but only when the code is not obfuscated**.
///
/// If you are obfuscating your final code, or if you want to provide a
/// different name or additional view attributes, you should override the
/// [rumViewInfo] getter.
///
/// [DatadogNavigationObserver] uses the [didChangeDependencies] lifecycle
/// method to start the RUM view. For this reason, you should avoid calling RUM
/// methods during [initState], and override [didPush] from [RouteAware] to do
/// any initial setup instead.
///
/// Note: this should not be used with named routes. By design, the Mixin checks
/// if a name was already assigned to its route and will not send any tracking
/// events in that case
mixin DatadogRouteAwareMixin<T extends StatefulWidget> on State<T>, RouteAware {
  DatadogNavigationObserver? _routeObserver;

  /// Override this method to supply extra view info for this view through the
  /// [RumViewInfo] class. By default, it returns the name of the parent Widget
  /// as the name of the view.
  RumViewInfo get rumViewInfo {
    return RumViewInfo(name: (T).toString());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _routeObserver = DatadogNavigationObserverProvider.of(context)?.navObserver;
    if (_routeObserver != null) {
      final route = ModalRoute.of(context);
      if (route != null) {
        if (route.settings.name == null) {
          _routeObserver?.subscribe(this, route);
        } else {
          DatadogSdk.instance.internalLogger.info(
              '$DatadogRouteAwareMixin for ${rumViewInfo.name} (on widget $T) '
              'will be ignored because it is part of a named route ${route.settings.name}');
        }
      }
    } else {
      DatadogSdk.instance.internalLogger.warn(
          'Invalid use of $DatadogRouteAwareMixin without a $DatadogNavigationObserverProvider. '
          'Make sure to add the provider at the root of your widget tree (above your MaterialApp)');
    }
  }

  @override
  void dispose() {
    _routeObserver?.unsubscribe(this);
    super.dispose();
  }

  @override
  @mustCallSuper
  void didPush() {
    _startView();
    super.didPush();
  }

  @override
  @mustCallSuper
  void didPop() {
    super.didPop();
    _stopView();
  }

  @override
  @mustCallSuper
  void didPushNext() {
    super.didPushNext();
    _stopView();
  }

  @override
  @mustCallSuper
  void didPopNext() {
    _startView();
    super.didPopNext();
  }

  void _startView() {
    if (_routeObserver != null) {
      final info = rumViewInfo;
      _routeObserver?.datadogSdk.rum
          ?.startView(info.name, null, info.attributes);
    }
  }

  void _stopView() {
    if (_routeObserver != null) {
      final info = rumViewInfo;
      _routeObserver?.datadogSdk.rum?.stopView(info.name);
    }
  }
}

/// Provides the [DatadogNavigationObserver] to other classes that need it.
/// Specifically, if you want to use the [DatadogRouteAwareMixin], you must use
/// this provider.
///
/// The provider should be placed in the widget tree above your MaterialApp or
/// application router.
/// ```
/// void main() {
///   // Other setup code
///   final observer = DatadogNavigationObserver(datadogSdk: DatadogSdk.instance);
///   runApp(DatadogNavigationObserverProvider(
///     navObserver: observer,
///     child: MaterialApp(
///       navigatorObservers: [observer],
///       // other initialization
///     ),
///   );
/// }
/// ```
///
/// See also [DatadogRouteAwareMixin]
class DatadogNavigationObserverProvider extends InheritedWidget {
  final DatadogNavigationObserver navObserver;

  const DatadogNavigationObserverProvider({
    Key? key,
    required this.navObserver,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  bool updateShouldNotify(
          covariant DatadogNavigationObserverProvider oldWidget) =>
      navObserver != oldWidget.navObserver;

  static DatadogNavigationObserverProvider? of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<
        DatadogNavigationObserverProvider>();
    return result;
  }
}
