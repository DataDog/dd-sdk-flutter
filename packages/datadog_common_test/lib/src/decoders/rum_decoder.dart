// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:io';

import 'package:flutter/foundation.dart';

class RumSessionDecoder {
  final List<RumViewVisit> visits;

  RumSessionDecoder(this.visits);

  static RumSessionDecoder fromEvents(List<RumEventDecoder> events,
      {bool shouldDiscardApplicationLaunch = true}) {
    events.sort((firstEvent, secondEvent) {
      var comp = firstEvent.date.compareTo(secondEvent.date);
      // In the BrowserSDK, view events always have their date set to the start of the view
      // Sort based off time spent
      if (comp == 0 &&
          firstEvent.eventType == 'view' &&
          secondEvent.eventType == 'view') {
        final firstView = RumViewEventDecoder(firstEvent.rumEvent);
        final secondView = RumViewEventDecoder(secondEvent.rumEvent);
        return firstView.timeSpent.compareTo(secondView.timeSpent);
      }
      return comp;
    });

    final viewVisitsById = <String, RumViewVisit>{};
    for (var e in events.where((e) => e.eventType == 'view')) {
      final viewEvent = RumViewEventDecoder(e.rumEvent);
      var visit = viewVisitsById[viewEvent.view.id];
      if (visit == null) {
        visit = RumViewVisit(
            viewEvent.view.id, viewEvent.view.name, viewEvent.view.path);
        viewVisitsById[viewEvent.view.id] = visit;
      }
      visit.viewEvents.add(viewEvent);
    }

    for (var e in events.where((e) => e.eventType != 'view')) {
      var visit = viewVisitsById[e.view.id];
      if (visit == null) {
        continue;
      }
      switch (e.eventType) {
        case 'action':
          final actionEvent = RumActionEventDecoder(e.rumEvent);
          visit.actionEvents.add(actionEvent);
          break;
        case 'resource':
          final resourceEvent = RumResourceEventDecoder(e.rumEvent);
          visit.resourceEvents.add(resourceEvent);
          break;
        case 'error':
          final errorEvent = RumErrorEventDecoder(e.rumEvent);
          visit.errorEvents.add(errorEvent);
          break;
      }
    }

    if (shouldDiscardApplicationLaunch) {
      viewVisitsById
          .removeWhere((key, value) => value.name == 'ApplicationLaunch');
    }

    return RumSessionDecoder(viewVisitsById.values.toList());
  }
}

class RumViewVisit {
  final String id;
  final String name;
  final String path;

  final List<RumViewEventDecoder> viewEvents = [];
  final List<RumActionEventDecoder> actionEvents = [];
  final List<RumResourceEventDecoder> resourceEvents = [];
  final List<RumErrorEventDecoder> errorEvents = [];

  RumViewVisit(this.id, this.name, this.path);
}

class Dd {
  final Map<String, dynamic> rawData;

  Dd(this.rawData);

  String? get traceId => rawData['trace_id'];
  String? get spanId => rawData['span_id'];
}

class RumEventDecoder {
  final Map<String, dynamic> rumEvent;
  final RumViewDecoder view;
  final Dd dd;

  String get eventType => rumEvent['type'] as String;
  String get service {
    if (!kIsWeb) {
      if (Platform.isIOS) return rumEvent['service'];
    }
    return rumEvent['service'];
  }

  int get date => rumEvent['date'] as int;

  Map<String, dynamic>? get context => rumEvent['context'];

  RumEventDecoder(this.rumEvent)
      : view = RumViewDecoder(rumEvent['view']),
        dd = Dd(rumEvent['_dd']);

  static RumEventDecoder? fromJson(Map<String, dynamic> eventData) {
    if (eventData['view'] != null &&
        eventData['type'] != null &&
        eventData['_dd'] != null) {
      return RumEventDecoder(eventData);
    }

    return null;
  }
}

class RumViewEventDecoder extends RumEventDecoder {
  int get timeSpent => rumEvent['view']['time_spent'] as int;

  RumViewEventDecoder(Map<String, dynamic> rumEvent) : super(rumEvent);
}

class RumActionEventDecoder extends RumEventDecoder {
  RumActionEventDecoder(Map<String, dynamic> rumEvent) : super(rumEvent);

  String get actionType => rumEvent['action']['type'];
  String get actionName => rumEvent['action']['target']?['name'];
  int get loadingTime => rumEvent['action']['loading_time'];
}

class RumResourceEventDecoder extends RumEventDecoder {
  RumResourceEventDecoder(Map<String, dynamic> rumEvent) : super(rumEvent);

  String get url => rumEvent['resource']['url'];
  int? get statusCode => rumEvent['resource']['status_code'];
  String? get resourceType => rumEvent['resource']['type'];
  int? get duration => rumEvent['resource']['duration'];
  String? get method => rumEvent['resource']['method'];
}

class RumErrorEventDecoder extends RumEventDecoder {
  RumErrorEventDecoder(Map<String, dynamic> rumEvent) : super(rumEvent);

  String get errorType => rumEvent['error']['type'];
  String get message => rumEvent['error']['message'];
  String get stack => rumEvent['error']['stack'];
  String get source => rumEvent['error']['source'];
  String get sourceType => rumEvent['error']['source_type'];

  String? get resourceUrl => rumEvent['error']['resource']?['url'];
  String? get resourceMethod => rumEvent['error']['resource']?['method'];
  int? get resourceStatusCode => rumEvent['error']['resource']?['statusCode'];
}

class RumViewDecoder {
  final Map<String, dynamic> viewData;

  String get id => viewData['id'] as String;
  String get name => viewData['name'] as String;
  String get path => viewData['url'] as String;
  bool get isActive => viewData['is_active'] as bool;
  int get actionCount => viewData['action']['count'] as int;
  int get resourceCount => viewData['resource']['count'] as int;
  int get errorCount => viewData['error']['count'] as int;

  Map<String, int> get customTimings =>
      (viewData['custom_timings'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, value as int));

  RumViewDecoder(this.viewData);
}
