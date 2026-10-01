// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:io';

import 'package:collection/collection.dart';

import '../is_web.dart';

class RumUser {
  Map<String, Object?> raw;
  String? email;
  String? id;
  String? name;

  RumUser(this.raw, this.email, this.id, this.name);

  static RumUser fromJson(Map<String, dynamic> json) {
    final email = json['email'] is String ? json['email'] as String : null;
    final id = json['id'] is String ? json['id'] as String : null;
    final name = json['name'] is String ? json['name'] as String : null;
    return RumUser(json, email, id, name);
  }
}

class RumSessionDecoder {
  final List<RumViewVisit> visits;

  RumSessionDecoder(this.visits);

  static List<RumSessionDecoder> fromEvents(
    List<RumEventDecoder> events, {
    bool shouldDiscardApplicationLaunch = true,
  }) {
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

    final sessionViewEventsById =
        <String, Map<String, List<RumEventDecoder>>>{};
    final sessionOrder = <String>[];

    for (var e in events.where(_isViewEvent)) {
      final viewId = e.viewInfo?.id;
      if (viewId == null) continue;
      final sessionId = e.sessionId ?? '';
      if (!sessionViewEventsById.containsKey(sessionId)) {
        sessionViewEventsById[sessionId] = {};
        sessionOrder.add(sessionId);
      }
      sessionViewEventsById[sessionId]!.putIfAbsent(viewId, () => []).add(e);
    }

    final sessionViewVisits = <String, Map<String, RumViewVisit>>{};
    for (final sessionEntry in sessionViewEventsById.entries) {
      final viewVisitsById = <String, RumViewVisit>{};
      for (final entry in sessionEntry.value.entries) {
        final viewEvents = entry.value;
        mergeSort(
          viewEvents,
          compare: (a, b) => a.documentVersion.compareTo(b.documentVersion),
        );

        RumViewVisit? visit;
        Map<String, dynamic>? state;
        for (final e in viewEvents) {
          if (e.eventType == 'view') {
            state = e.rumEvent;
          } else if (state != null) {
            state = _applyViewUpdate(state, e.rumEvent);
          } else {
            // No baseline received (yet) to apply this delta to
            continue;
          }
          final viewEvent = RumViewEventDecoder(state);
          visit ??= RumViewVisit(
            viewEvent.view.id,
            viewEvent.view.name,
            viewEvent.view.path,
          );
          visit.viewEvents.add(viewEvent);
        }
        if (visit != null) {
          viewVisitsById[entry.key] = visit;
        }
      }
      sessionViewVisits[sessionEntry.key] = viewVisitsById;
    }

    for (var e in events.where((e) => !_isViewEvent(e))) {
      var viewId = e.viewInfo?.id;
      if (viewId == null) {
        continue;
      }
      final sessionId = e.sessionId ?? '';
      final viewVisitsById = sessionViewVisits[sessionId];
      if (viewVisitsById == null) {
        continue;
      }
      var visit = viewVisitsById[viewId];
      if (visit == null) {
        continue;
      }
      switch (e.eventType) {
        case 'action':
          visit.actionEvents.add(RumActionEventDecoder(e.rumEvent));
          break;
        case 'resource':
          visit.resourceEvents.add(RumResourceEventDecoder(e.rumEvent));
          break;
        case 'error':
          visit.errorEvents.add(RumErrorEventDecoder(e.rumEvent));
          break;
        case 'long_task':
          visit.longTaskEvents.add(RumLongTaskEventDecoder(e.rumEvent));
          break;
        case 'vital':
          final operationStepEvent = RumVitalOperationStepEventDecoder(
            e.rumEvent,
          );
          visit.vitalStepEvents.add(operationStepEvent);
          break;
      }
    }

    if (shouldDiscardApplicationLaunch) {
      for (var viewVisitsById in sessionViewVisits.values) {
        viewVisitsById.removeWhere(
          (key, value) => value.name == 'ApplicationLaunch',
        );
      }
    }

    return sessionOrder
        .map((id) => RumSessionDecoder(sessionViewVisits[id]!.values.toList()))
        .where((s) => s.visits.isNotEmpty)
        .toList();
  }

  static bool _isViewEvent(RumEventDecoder e) =>
      e.eventType == 'view' || e.eventType == 'view_update';

  // `view_update` events only contain changed fields. `view` and
  // `view.accessibility` are diffed per field, everything else is sent whole.
  static Map<String, dynamic> _applyViewUpdate(
    Map<String, dynamic> base,
    Map<String, dynamic> update,
  ) {
    final merged = Map<String, dynamic>.of(base);
    for (final entry in update.entries) {
      if (entry.key == 'type') continue;
      if (entry.key == 'view') {
        final view = Map<String, dynamic>.of(base['view']);
        final viewUpdate = entry.value as Map<String, dynamic>;
        for (final viewEntry in viewUpdate.entries) {
          if (viewEntry.key == 'accessibility' &&
              view['accessibility'] is Map<String, dynamic>) {
            view['accessibility'] = {
              ...view['accessibility'] as Map<String, dynamic>,
              ...viewEntry.value as Map<String, dynamic>,
            };
          } else {
            view[viewEntry.key] = viewEntry.value;
          }
        }
        merged['view'] = view;
      } else {
        merged[entry.key] = entry.value;
      }
    }
    return merged;
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
  final List<RumVitalOperationStepEventDecoder> vitalStepEvents = [];

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

  String? get eventType => rumEvent['type'] as String?;
  String get service {
    if (!testIsWeb()) {
      if (Platform.isIOS) return rumEvent['service'];
    }
    return rumEvent['service'];
  }

  RumUser? get user {
    final usr = rumEvent['usr'];
    if (usr == null) return null;
    return RumUser.fromJson(usr);
  }

  String? get sessionId {
    final session = rumEvent['session'] as Map<String, dynamic>?;
    return session?['id'] as String?;
  }

  int get date => rumEvent['date'] as int;
  int get documentVersion =>
      (rumEvent['_dd']?['document_version'] as int?) ?? 0;
  String get version => rumEvent['version'] as String;
  Map<String, dynamic>? get telemetryConfiguration =>
      rumEvent['telemetry']?['configuration'];

  Map<String, dynamic>? get context => rumEvent['context'];
  Map<String, dynamic>? get featureFlags =>
      rumEvent['feature_flags'] ?? <String, dynamic>{};

  Map<String, String> get ddtags {
    final tagMap = <String, String>{};
    final rawTags = rumEvent['ddtags'] as String?;
    if (rawTags == null) return tagMap;

    for (var tag in rawTags.split(',')) {
      var colon = tag.indexOf(':');
      if (colon == -1) {
        tagMap[tag] = '';
      } else {
        tagMap[tag.substring(0, colon)] = tag.substring(colon + 1);
      }
    }

    return tagMap;
  }

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

  Vital({required this.minTime, required this.maxTime, required this.avgTime});
}

class Performance {
  final Map<String, Object?> encoded;

  int? get fbc {
    final fbcObj = encoded['fbc'];
    if (fbcObj is Map<String, Object?>) {
      final fbcTimeStamp = fbcObj['timestamp'];
      if (fbcTimeStamp is int) return fbcTimeStamp;
    }

    return null;
  }

  Performance(this.encoded);
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

  int? get inv {
    final invValue = rumEvent['view']['interaction_to_next_view_time'];
    return invValue as int?;
  }

  Performance? get performance {
    final perf = rumEvent['view']['performance'] as Map<String, Object?>?;
    if (perf != null) {
      return Performance(perf);
    }
    return null;
  }

  RumViewEventDecoder(super.rumEvent) : view = RumViewDecoder(rumEvent['view']);
}

class RumActionEventDecoder extends RumEventDecoder {
  RumActionEventDecoder(super.rumEvent);

  String get actionType => rumEvent['action']['type'];
  String get actionName => rumEvent['action']['target']?['name'];
  int get loadingTime => rumEvent['action']['loading_time'];
}

class RumResourceEventDecoder extends RumEventDecoder {
  RumResourceEventDecoder(super.rumEvent);

  String get url => rumEvent['resource']['url'];
  int? get statusCode => rumEvent['resource']['status_code'];
  String? get resourceType => rumEvent['resource']['type'];
  int? get duration => rumEvent['resource']['duration'];
  String? get method => rumEvent['resource']['method'];
  int? get size => rumEvent['resource']['size'];

  Map<String, String>? get requestHeaders {
    final raw = rumEvent['resource']?['request']?['headers'];
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return null;
  }

  Map<String, String>? get responseHeaders {
    final raw = rumEvent['resource']?['response']?['headers'];
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return null;
  }
}

class RumErrorEventDecoder extends RumEventDecoder {
  RumErrorEventDecoder(super.rumEvent);

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
  RumLongTaskEventDecoder(super.rumEvent);

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
  int? get networkSettledTime => viewData['network_settled_time'] as int?;

  Map<String, int> get customTimings =>
      (viewData['custom_timings'] as Map<String, Object?>).map(
        (key, value) => MapEntry(key, value as int),
      );

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

class RumVitalOperationStepEventDecoder extends RumEventDecoder {
  RumVitalOperationStepEventDecoder(super.rumEvent);

  RumViewInfoDecoder get view => RumViewInfoDecoder(rumEvent['view']);

  String get vitalName => rumEvent['vital']['name'] as String;
  String? get vitalOperationKey =>
      rumEvent['vital']['operation_key'] as String?;
  String? get vitalFailureReason =>
      rumEvent['vital']['failure_reason'] as String?;
  String get stepType => rumEvent['vital']['step_type'] as String;
}
