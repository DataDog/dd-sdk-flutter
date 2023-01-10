// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:json_annotation/json_annotation.dart';

import '../json_helpers.dart';

part 'ddrum_events.g.dart';

@commonJsonOptions
class RumViewEvent {
  @JsonKey(name: '_dd')
  final RumViewEventDd dd;
  // Application
  // CITest
  final RumConnectivity? connectivity;
  @JsonKey(fromJson: attributesFromJson)
  final Map<String, Object?> context;
  final int date;
  // Device
  // Display
  // FeatureFlags
  // os
  final String service;
  final RumViewEventSession session;
  // usr
  final String version;
  final RumViewDetails view;

  RumViewEvent({
    required this.dd,
    this.connectivity,
    required this.context,
    required this.date,
    required this.service,
    required this.session,
    required this.version,
    required this.view,
  });

  factory RumViewEvent.fromJson(Map<dynamic, dynamic> json) =>
      _$RumViewEventFromJson(json);
  Map<String, dynamic> toJson() => _$RumViewEventToJson(this);
}

@commonJsonOptions
class RumViewEventDd {
  final int documentVersion;
  final int formatVersion;

  RumViewEventDd({
    required this.documentVersion,
    required this.formatVersion,
  });

  factory RumViewEventDd.fromJson(Map<String, dynamic> json) =>
      _$RumViewEventDdFromJson(json);
  Map<String, dynamic> toJson() => _$RumViewEventDdToJson(this);
}

enum RumConnectivityInterfaces {
  bluetooth,
  cellular,
  ethernet,
  wifi,
  wimax,
  mixed,
  other,
  unknown,
  none,
}

enum RumConnectivityStatus {
  connected,
  @JsonValue('not_connected')
  notConnected,
  maybe,
}

@commonJsonOptions
class RumConnectivity {
  final RumCellular? cellular;
  final List<RumConnectivityInterfaces> interfaces;
  final RumConnectivityStatus status;

  RumConnectivity({
    this.cellular,
    required this.interfaces,
    required this.status,
  });

  factory RumConnectivity.fromJson(Map<String, dynamic> json) =>
      _$RumConnectivityFromJson(json);
  Map<String, dynamic> toJson() => _$RumConnectivityToJson(this);
}

@JsonSerializable()
class RumCellular {
  final String carrierName;
  final String technology;

  RumCellular({
    required this.carrierName,
    required this.technology,
  });

  factory RumCellular.fromJson(Map<String, dynamic> json) =>
      _$RumCellularFromJson(json);
  Map<String, dynamic> toJson() => _$RumCellularToJson(this);
}

@commonJsonOptions
class RumViewEventSession {
  final bool? hasReplay;
  final String id;
  final String type;

  RumViewEventSession({
    this.hasReplay,
    required this.id,
    required this.type,
  });

  factory RumViewEventSession.fromJson(Map<String, dynamic> json) =>
      _$RumViewEventSessionFromJson(json);
  Map<String, dynamic> toJson() => _$RumViewEventSessionToJson(this);
}

@commonJsonOptions
class RumViewDetails {
  final RumCount action;
  final double? cpuTicksCount;
  final double? cpuTicksPerSecond;
  final RumCount crash;
  final Map<String, int>? customTimings;
  final RumCount error;
  final RumPerformanceMetric? flutterBuildTime;
  final RumPerformanceMetric? flutterRasterTime;
  // frozenframe
  // frustration
  final String id;
  final bool? isActive;
  final bool? isSlowRendered;
  final RumCount? longTask;
  final double? memoryAverage;
  final double? memoryMax;
  String? name;
  String? referrer;
  final double? refreshRateAverage;
  final double? refreshRateMin;
  final RumCount resource;
  final int timeSpent;
  String url;

  RumViewDetails(
      {required this.action,
      this.cpuTicksCount,
      this.cpuTicksPerSecond,
      required this.crash,
      this.customTimings,
      required this.error,
      this.flutterBuildTime,
      this.flutterRasterTime,
      required this.id,
      this.isActive,
      this.isSlowRendered,
      this.longTask,
      this.memoryAverage,
      this.memoryMax,
      this.name,
      this.referrer,
      this.refreshRateAverage,
      this.refreshRateMin,
      required this.resource,
      required this.timeSpent,
      required this.url});

  factory RumViewDetails.fromJson(Map<String, dynamic> json) =>
      _$RumViewDetailsFromJson(json);
  Map<String, dynamic> toJson() => _$RumViewDetailsToJson(this);
}

// This is a common construct in the View event, but has separate types in the schema for
// Action, Error, Crash, Resource, etc. For simplicity we combine them into one type
@commonJsonOptions
class RumCount {
  final int count;

  RumCount({
    required this.count,
  });

  factory RumCount.fromJson(Map<String, dynamic> json) =>
      _$RumCountFromJson(json);
  Map<String, dynamic> toJson() => _$RumCountToJson(this);
}

// This is a common construct in the View event, but has separate types in the schema for
// build time and raster time. For simplicity we combine them into one type
@commonJsonOptions
class RumPerformanceMetric {
  final double average;
  final double max;
  final double metricMax;
  final double min;

  RumPerformanceMetric(
      {required this.average,
      required this.max,
      required this.metricMax,
      required this.min});

  factory RumPerformanceMetric.fromJson(Map<String, dynamic> json) =>
      _$RumPerformanceMetricFromJson(json);
  Map<String, dynamic> toJson() => _$RumPerformanceMetricToJson(this);
}
