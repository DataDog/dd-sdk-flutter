// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

class RumSessionDecoder {
  final List<RumViewVisit> visits;

  RumSessionDecoder(this.visits);

  static RumSessionDecoder fromEvents(List<RumEventDecoder> events) {
    events.sort((firstEvent, secondEvent) =>
        firstEvent.date.compareTo(secondEvent.date));

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
      switch (e.eventType) {
        case 'action':
          var visit = viewVisitsById[e.view.id];
          if (visit != null) {
            final actionEvent = RumActionEventDecoder(e.rumEvent);
            visit.actionEvents.add(actionEvent);
          }
          break;
        case 'resource':
          var visit = viewVisitsById[e.view.id];
          if (visit != null) {
            final resourceEvent = RumResourceEventDecoder(e.rumEvent);
            visit.resourceEvents.add(resourceEvent);
          }
          break;
      }
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

  RumViewVisit(this.id, this.name, this.path);
}

class RumEventDecoder {
  final Map<String, dynamic> rumEvent;
  final RumViewDecoder view;

  String get eventType => rumEvent['type'] as String;
  int get date => rumEvent['date'] as int;

  RumEventDecoder(this.rumEvent) : view = RumViewDecoder(rumEvent['view']);
}

class RumViewEventDecoder extends RumEventDecoder {
  RumViewEventDecoder(Map<String, dynamic> rumEvent) : super(rumEvent);
}

class RumActionEventDecoder extends RumEventDecoder {
  RumActionEventDecoder(Map<String, dynamic> rumEvent) : super(rumEvent);

  String get actionType => rumEvent['action']['type'];
}

class RumResourceEventDecoder extends RumEventDecoder {
  RumResourceEventDecoder(Map<String, dynamic> rumEvent) : super(rumEvent);
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
