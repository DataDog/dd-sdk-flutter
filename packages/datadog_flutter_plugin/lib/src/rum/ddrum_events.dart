// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:json_annotation/json_annotation.dart';

import '../../datadog_flutter_plugin.dart';
import '../json_helpers.dart';

part 'ddrum_events.g.dart';

// Currently excluded
//  * ciTest
//  * display
//  * featureFlags
//  * source
//  * synthetics
@commonJsonOptions
class RumViewEvent {
  @JsonKey(name: '_dd')
  final RumViewEventDd dd;
  final RumApplication application;
  final RumConnectivity? connectivity;
  @JsonKey(fromJson: attributesFromJson)
  final Map<String, Object?> context;
  final int date;
  final RumDevice? device;
  final RumOperatingSystem? os;
  final String service;
  final RumSession session;
  final RumUser? usr;
  final String version;
  final RumViewDetails view;

  RumViewEvent({
    required this.dd,
    required this.application,
    this.connectivity,
    required this.context,
    required this.date,
    this.device,
    this.os,
    required this.service,
    required this.session,
    this.usr,
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

@commonJsonOptions
class RumApplication {
  final String id;

  RumApplication({
    required this.id,
  });

  factory RumApplication.fromJson(Map<String, dynamic> json) =>
      _$RumApplicationFromJson(json);
  Map<String, dynamic> toJson() => _$RumApplicationToJson(this);
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
class RumSession {
  final bool? hasReplay;
  final String id;
  final String type;

  RumSession({
    this.hasReplay,
    required this.id,
    required this.type,
  });

  factory RumSession.fromJson(Map<String, dynamic> json) =>
      _$RumSessionFromJson(json);
  Map<String, dynamic> toJson() => _$RumSessionToJson(this);
}

enum RumDeviceType {
  mobile,
  desktop,
  tablet,
  tv,
  @JsonValue('gaming_console')
  gamingConsole,
  bot,
  other,
}

@commonJsonOptions
class RumDevice {
  final String? architecture;
  final String? brand;
  final String? model;
  final String? name;
  final RumDeviceType type;

  RumDevice({
    this.architecture,
    this.brand,
    this.model,
    this.name,
    required this.type,
  });

  factory RumDevice.fromJson(Map<String, dynamic> json) =>
      _$RumDeviceFromJson(json);
  Map<String, dynamic> toJson() => _$RumDeviceToJson(this);
}

@commonJsonOptions
class RumOperatingSystem {
  final String name;
  final String version;
  final String versionMajor;

  RumOperatingSystem({
    required this.name,
    required this.version,
    required this.versionMajor,
  });

  factory RumOperatingSystem.fromJson(Map<String, dynamic> json) =>
      _$RumOperatingSystemFromJson(json);
  Map<String, dynamic> toJson() => _$RumOperatingSystemToJson(this);
}

@commonJsonOptions
class RumUser {
  final String? email;
  final String? id;
  final String? name;

  @JsonKey(fromJson: attributesFromJson)
  final Map<String, Object?> usrInfo;

  RumUser({
    this.email,
    this.id,
    this.name,
    this.usrInfo = const {},
  });

  factory RumUser.fromJson(Map<String, dynamic> json) =>
      _$RumUserFromJson(json);
  Map<String, dynamic> toJson() => _$RumUserToJson(this);
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
  final RumCount? frozenFrame;
  final RumCount? frustration;
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

  RumViewDetails({
    required this.action,
    this.cpuTicksCount,
    this.cpuTicksPerSecond,
    required this.crash,
    this.customTimings,
    required this.error,
    this.flutterBuildTime,
    this.flutterRasterTime,
    this.frozenFrame,
    this.frustration,
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
    required this.url,
  });

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

// Excluded:
// * _dd
// * ciTest
// * display
// * source
// * synthetics
@commonJsonOptions
class RumActionEvent {
  final RumAction action;
  final RumApplication application;
  final RumConnectivity? connectivity;
  final int date;
  final RumDevice? device;
  final RumOperatingSystem? os;
  final String? service;
  final RumSession session;
  final RumUser? usr;
  final String? version;
  final RumViewSummary view;

  @JsonKey(fromJson: attributesFromJson)
  final Map<String, Object?> context;

  RumActionEvent({
    required this.action,
    required this.application,
    this.connectivity,
    required this.date,
    this.device,
    this.os,
    this.service,
    required this.session,
    required this.usr,
    this.version,
    required this.view,
    required this.context,
  });

  factory RumActionEvent.fromJson(Map<dynamic, dynamic> json) =>
      _$RumActionEventFromJson(json);
  Map<String, dynamic> toJson() => _$RumActionEventToJson(this);
}

enum RumActionType {
  custom,
  click,
  tap,
  scroll,
  swipe,
  @JsonValue('application_start')
  applicationStart,
  back,
}

@commonJsonOptions
class RumAction {
  final RumCount? crash;
  final RumCount? error;
  final RumActionFrustration? frustration;
  final String? id;
  final int? loadingTime;
  final RumCount? longTask;
  final RumCount? resource;
  final RumActionTarget? target;
  final RumActionType type;

  RumAction({
    this.crash,
    this.error,
    this.frustration,
    this.id,
    this.loadingTime,
    this.longTask,
    this.resource,
    this.target,
    required this.type,
  });

  factory RumAction.fromJson(Map<String, dynamic> json) =>
      _$RumActionFromJson(json);
  Map<String, dynamic> toJson() => _$RumActionToJson(this);
}

@JsonSerializable()
class RumActionTarget {
  String name;

  RumActionTarget({
    required this.name,
  });

  factory RumActionTarget.fromJson(Map<String, dynamic> json) =>
      _$RumActionTargetFromJson(json);
  Map<String, dynamic> toJson() => _$RumActionTargetToJson(this);
}

@commonJsonOptions
class RumViewSummary {
  final String id;
  final bool? inForeground;
  String? name;
  String? referrer;
  String url;

  RumViewSummary({
    required this.id,
    this.inForeground,
    this.name,
    this.referrer,
    required this.url,
  });

  factory RumViewSummary.fromJson(Map<String, dynamic> json) =>
      _$RumViewSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$RumViewSummaryToJson(this);
}

@JsonEnum(fieldRename: FieldRename.snake)
enum RumFrustrationType {
  rageClick,
  deadClick,
  errorClick,
  rageTap,
  errorTap,
}

@commonJsonOptions
class RumActionFrustration {
  final List<RumActionFrustration> type;

  RumActionFrustration({
    required this.type,
  });

  factory RumActionFrustration.fromJson(Map<String, dynamic> json) =>
      _$RumActionFrustrationFromJson(json);
  Map<String, dynamic> toJson() => _$RumActionFrustrationToJson(this);
}

// Excluded:
//   * All timings (not available to Flutter) --
//      (Connect, DNS, Download, FirstByte, SSL, Redirect)
//   * provider
@commonJsonOptions
class RumResource {
  final int duration;
  final String? id;
  final String method;
  // Provider
  final int? size;
  final int? statusCode;
  final RumResourceType type;
  String url;

  RumResource({
    required this.duration,
    this.id,
    required this.method,
    this.size,
    this.statusCode,
    required this.type,
    required this.url,
  });

  factory RumResource.fromJson(Map<String, dynamic> json) =>
      _$RumResourceFromJson(json);
  Map<String, dynamic> toJson() => _$RumResourceToJson(this);
}

// Excluded:
//  * dd
//  * ciTest
//  * display
//  * synthectics
@commonJsonOptions
class RumResourceEvent {
  @JsonKey(fromJson: actionListFromJson)
  final List<String>? action;
  final RumApplication application;
  final RumConnectivity? connectivity;
  final int date;
  final RumDevice? device;
  final RumOperatingSystem? os;
  final RumResource resource;
  final String? service;
  final RumUser? usr;
  final String? version;
  final RumViewSummary? view;

  @JsonKey(fromJson: attributesFromJson)
  final Map<String, Object?> context;

  RumResourceEvent({
    this.action,
    required this.application,
    this.connectivity,
    required this.date,
    this.device,
    this.os,
    this.service,
    required this.resource,
    this.usr,
    this.version,
    this.view,
    required this.context,
  });

  factory RumResourceEvent.fromJson(Map<dynamic, dynamic> json) =>
      _$RumResourceEventFromJson(json);
  Map<String, dynamic> toJson() => _$RumResourceEventToJson(this);
}
