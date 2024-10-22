// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:io';

import '../../datadog_common_test.dart';

class RumUser {
  String? email;
  String? id;
  String? name;

  RumUser(this.email, this.id, this.name);

  static RumUser fromJson(Map<String, dynamic> json) {
    final email = json['email'] is String ? json['email'] as String : null;
    final id = json['id'] is String ? json['id'] as String : null;
    final name = json['name'] is String ? json['name'] as String : null;
    return RumUser(email, id, name);
  }
}

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
      var viewId = e.viewInfo?.id;
      if (viewId == null) {
        continue;
      }
      var visit = viewVisitsById[viewId];
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
        case 'long_task':
          final longTaskEvent = RumLongTaskEventDecoder(e.rumEvent);
          visit.longTaskEvents.add(longTaskEvent);
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
  final String? name;
  final String path;

  final List<RumViewEventDecoder> viewEvents = [];
  final List<RumActionEventDecoder> actionEvents = [];
  final List<RumResourceEventDecoder> resourceEvents = [];
  final List<RumErrorEventDecoder> errorEvents = [];
  final List<RumLongTaskEventDecoder> longTaskEvents = [];

  RumViewVisit(this.id, this.name, this.path);
}

class Dd {
  final Map<String, dynamic>? rawData;

  Dd(this.rawData);

  String? get traceId => rawData?['trace_id'];
  String? get spanId => rawData?['span_id'];
  int? get plan {
    final session = rawData?['session'] as Map<String, dynamic>?;
    return session?['plan'];
  }
}

class RumEventDecoder {
  final Map<String, dynamic> rumEvent;
  final RumViewInfoDecoder? viewInfo;
  final Dd dd;

  String get eventType => rumEvent['type'] as String;
  String get service {
    if (!kManualIsWeb) {
      if (Platform.isIOS) return rumEvent['service'];
    }
    return rumEvent['service'];
  }

  RumUser? get user {
    final usr = rumEvent['usr'];
    if (usr == null) return null;
    return RumUser.fromJson(usr);
  }

  int get date => rumEvent['date'] as int;
  String get version => rumEvent['version'] as String;
  Map<String, dynamic>? get telemetryConfiguration =>
      rumEvent['telemetry']?['configuration'];

  Map<String, dynamic>? get context => rumEvent['context'];
  Map<String, dynamic>? get featureFlags =>
      rumEvent['feature_flags'] ?? <String, dynamic>{};

  RumEventDecoder(this.rumEvent)
      : viewInfo = RumViewInfoDecoder(rumEvent['view']),
        dd = Dd(rumEvent['_dd']);

  static RumEventDecoder? fromJson(Map<String, dynamic> eventData) {
    if (eventData['type'] != null && eventData['_dd'] != null) {
      return RumEventDecoder(eventData);
    }

    return null;
  }
}

class Vital {
  final double minTime;
  final double maxTime;
  final double avgTime;

  Vital({
    required this.minTime,
    required this.maxTime,
    required this.avgTime,
  });
}

class RumViewEventDecoder extends RumEventDecoder {
  final RumViewDecoder view;

  int get timeSpent => rumEvent['view']['time_spent'] as int;
  Vital? get flutterRasterTime {
    final rasterTime =
        rumEvent['view']['flutter_raster_time'] as Map<String, Object?>?;
    if (rasterTime != null) {
      return Vital(
        minTime: rasterTime['min'] as double,
        maxTime: rasterTime['max'] as double,
        avgTime: rasterTime['average'] as double,
      );
    }
    return null;
  }

  Vital? get flutterBuildTime {
    final buildTime =
        rumEvent['view']['flutter_build_time'] as Map<String, Object?>?;
    if (buildTime != null) {
      return Vital(
        minTime: buildTime['min'] as double,
        maxTime: buildTime['max'] as double,
        avgTime: buildTime['average'] as double,
      );
    }
    return null;
  }

  RumViewEventDecoder(Map<String, dynamic> rumEvent)
      : view = RumViewDecoder(rumEvent['view']),
        super(rumEvent);
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
  String get fingerprint => rumEvent['error']['fingerprint'];

  String? get resourceUrl => rumEvent['error']['resource']?['url'];
  String? get resourceMethod => rumEvent['error']['resource']?['method'];
  int? get resourceStatusCode => rumEvent['error']['resource']?['statusCode'];
}

class RumLongTaskEventDecoder extends RumEventDecoder {
  RumLongTaskEventDecoder(Map<String, dynamic> rumEvent) : super(rumEvent);

  String? get viewName => rumEvent['view']['name'];
  int? get duration => rumEvent['long_task']['duration'];
}

class RumViewDecoder {
  final Map<String, dynamic> viewData;

  String get id => viewData['id'] as String;
  String? get name => viewData['name'] as String?;
  String get path => viewData['url'] as String;
  bool get isActive => viewData['is_active'] as bool;
  int get actionCount => viewData['action']['count'] as int;
  int get resourceCount => viewData['resource']['count'] as int;
  int get errorCount => viewData['error']['count'] as int;
  int get longTaskCount => viewData['long_task']['count'] as int;
  int? get loadingTime => viewData['loading_time'] as int?;

  Map<String, int> get customTimings =>
      (viewData['custom_timings'] as Map<String, Object?>)
          .map((key, value) => MapEntry(key, value as int));

  RumViewDecoder(this.viewData);
}

// Similar to RumViewDecoder but can be null and with a subset of properties
class RumViewInfoDecoder {
  final Map<String, dynamic>? viewData;

  String? get id => viewData?['id'] as String?;
  String? get name => viewData?['name'] as String?;
  String? get path => viewData?['url'] as String?;

  RumViewInfoDecoder(this.viewData);
}
