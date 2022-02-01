// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:flutter/material.dart';

import '../../datadog_sdk.dart';

class RumViewInfo {
  final String name;
  final String? path;
  final String? service;
  final Map<String, dynamic> attributes;

  RumViewInfo({
    required this.name,
    this.path,
    this.service,
    this.attributes = const {},
  });
}

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

class DatadogNavigationObserver extends RouteObserver<ModalRoute<dynamic>> {
  final ViewInfoExtractor viewInfoExtractor;

  DatadogNavigationObserver(
      {this.viewInfoExtractor = defaultViewInfoExtractor});

  Future<void> _sendScreenView(Route? newRoute, Route? oldRoute) async {
    final oldRouteInfo = oldRoute != null ? viewInfoExtractor(oldRoute) : null;
    final newRouteInfo = newRoute != null ? viewInfoExtractor(newRoute) : null;

    if (oldRouteInfo != null) {
      await DatadogSdk.instance.rum?.stopView(oldRouteInfo.name);
    }
    if (newRouteInfo != null) {
      await DatadogSdk.instance.rum?.startView(newRouteInfo.name);
    }
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
    // On pop, the "previous" route is now the new roue.
    _sendScreenView(previousRoute, route);
    super.didPop(route, previousRoute);
  }
}
