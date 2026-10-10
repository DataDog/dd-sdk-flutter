// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ddrum_events.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RumViewEvent _$RumViewEventFromJson(Map json) => RumViewEvent(
  dd: RumViewEventDd.fromJson(Map<String, dynamic>.from(json['_dd'] as Map)),
  application: RumApplication.fromJson(
    Map<String, dynamic>.from(json['application'] as Map),
  ),
  connectivity: json['connectivity'] == null
      ? null
      : RumConnectivity.fromJson(
          Map<String, dynamic>.from(json['connectivity'] as Map),
        ),
  context: attributesFromJson(json['context'] as Map?),
  date: (json['date'] as num).toInt(),
  device: json['device'] == null
      ? null
      : RumDevice.fromJson(Map<String, dynamic>.from(json['device'] as Map)),
  os: json['os'] == null
      ? null
      : RumOperatingSystem.fromJson(
          Map<String, dynamic>.from(json['os'] as Map),
        ),
  service: json['service'] as String,
  session: RumSession.fromJson(
    Map<String, dynamic>.from(json['session'] as Map),
  ),
  usr: json['usr'] == null
      ? null
      : RumUser.fromJson(Map<String, dynamic>.from(json['usr'] as Map)),
  version: json['version'] as String,
  view: RumViewDetails.fromJson(Map<String, dynamic>.from(json['view'] as Map)),
);

Map<String, dynamic> _$RumViewEventToJson(RumViewEvent instance) =>
    <String, dynamic>{
      '_dd': instance.dd.toJson(),
      'application': instance.application.toJson(),
      'connectivity': ?instance.connectivity?.toJson(),
      'context': instance.context,
      'date': instance.date,
      'device': ?instance.device?.toJson(),
      'os': ?instance.os?.toJson(),
      'service': instance.service,
      'session': instance.session.toJson(),
      'usr': ?instance.usr?.toJson(),
      'version': instance.version,
      'view': instance.view.toJson(),
    };

RumViewEventDd _$RumViewEventDdFromJson(Map json) => RumViewEventDd(
  documentVersion: (json['document_version'] as num).toInt(),
  formatVersion: (json['format_version'] as num).toInt(),
);

Map<String, dynamic> _$RumViewEventDdToJson(RumViewEventDd instance) =>
    <String, dynamic>{
      'document_version': instance.documentVersion,
      'format_version': instance.formatVersion,
    };

RumApplication _$RumApplicationFromJson(Map json) =>
    RumApplication(id: json['id'] as String);

Map<String, dynamic> _$RumApplicationToJson(RumApplication instance) =>
    <String, dynamic>{'id': instance.id};

RumConnectivity _$RumConnectivityFromJson(Map json) => RumConnectivity(
  cellular: json['cellular'] == null
      ? null
      : RumCellular.fromJson(
          Map<String, dynamic>.from(json['cellular'] as Map),
        ),
  interfaces: (json['interfaces'] as List<dynamic>)
      .map((e) => $enumDecode(_$RumConnectivityInterfacesEnumMap, e))
      .toList(),
  status: $enumDecode(_$RumConnectivityStatusEnumMap, json['status']),
);

Map<String, dynamic> _$RumConnectivityToJson(RumConnectivity instance) =>
    <String, dynamic>{
      'cellular': ?instance.cellular?.toJson(),
      'interfaces': instance.interfaces
          .map((e) => _$RumConnectivityInterfacesEnumMap[e]!)
          .toList(),
      'status': _$RumConnectivityStatusEnumMap[instance.status]!,
    };

const _$RumConnectivityInterfacesEnumMap = {
  RumConnectivityInterfaces.bluetooth: 'bluetooth',
  RumConnectivityInterfaces.cellular: 'cellular',
  RumConnectivityInterfaces.ethernet: 'ethernet',
  RumConnectivityInterfaces.wifi: 'wifi',
  RumConnectivityInterfaces.wimax: 'wimax',
  RumConnectivityInterfaces.mixed: 'mixed',
  RumConnectivityInterfaces.other: 'other',
  RumConnectivityInterfaces.unknown: 'unknown',
  RumConnectivityInterfaces.none: 'none',
};

const _$RumConnectivityStatusEnumMap = {
  RumConnectivityStatus.connected: 'connected',
  RumConnectivityStatus.notConnected: 'not_connected',
  RumConnectivityStatus.maybe: 'maybe',
};

RumCellular _$RumCellularFromJson(Map<String, dynamic> json) => RumCellular(
  carrierName: json['carrierName'] as String?,
  technology: json['technology'] as String?,
);

Map<String, dynamic> _$RumCellularToJson(RumCellular instance) =>
    <String, dynamic>{
      'carrierName': instance.carrierName,
      'technology': instance.technology,
    };

RumSession _$RumSessionFromJson(Map json) => RumSession(
  hasReplay: json['has_replay'] as bool?,
  id: json['id'] as String,
  type: json['type'] as String,
);

Map<String, dynamic> _$RumSessionToJson(RumSession instance) =>
    <String, dynamic>{
      'has_replay': ?instance.hasReplay,
      'id': instance.id,
      'type': instance.type,
    };

RumDevice _$RumDeviceFromJson(Map json) => RumDevice(
  architecture: json['architecture'] as String?,
  brand: json['brand'] as String?,
  model: json['model'] as String?,
  name: json['name'] as String?,
  type: $enumDecode(_$RumDeviceTypeEnumMap, json['type']),
);

Map<String, dynamic> _$RumDeviceToJson(RumDevice instance) => <String, dynamic>{
  'architecture': ?instance.architecture,
  'brand': ?instance.brand,
  'model': ?instance.model,
  'name': ?instance.name,
  'type': _$RumDeviceTypeEnumMap[instance.type]!,
};

const _$RumDeviceTypeEnumMap = {
  RumDeviceType.mobile: 'mobile',
  RumDeviceType.desktop: 'desktop',
  RumDeviceType.tablet: 'tablet',
  RumDeviceType.tv: 'tv',
  RumDeviceType.gamingConsole: 'gaming_console',
  RumDeviceType.bot: 'bot',
  RumDeviceType.other: 'other',
};

RumOperatingSystem _$RumOperatingSystemFromJson(Map json) => RumOperatingSystem(
  name: json['name'] as String,
  version: json['version'] as String,
  versionMajor: json['version_major'] as String,
);

Map<String, dynamic> _$RumOperatingSystemToJson(RumOperatingSystem instance) =>
    <String, dynamic>{
      'name': instance.name,
      'version': instance.version,
      'version_major': instance.versionMajor,
    };

RumUser _$RumUserFromJson(Map json) => RumUser(
  email: json['email'] as String?,
  id: json['id'] as String?,
  name: json['name'] as String?,
  usrInfo: json['usr_info'] == null
      ? const {}
      : attributesFromJson(json['usr_info'] as Map?),
);

Map<String, dynamic> _$RumUserToJson(RumUser instance) => <String, dynamic>{
  'email': ?instance.email,
  'id': ?instance.id,
  'name': ?instance.name,
  'usr_info': instance.usrInfo,
};

RumViewDetails _$RumViewDetailsFromJson(Map json) => RumViewDetails(
  action: RumCount.fromJson(Map<String, dynamic>.from(json['action'] as Map)),
  cpuTicksCount: (json['cpu_ticks_count'] as num?)?.toDouble(),
  cpuTicksPerSecond: (json['cpu_ticks_per_second'] as num?)?.toDouble(),
  crash: RumCount.fromJson(Map<String, dynamic>.from(json['crash'] as Map)),
  customTimings: (json['custom_timings'] as Map?)?.map(
    (k, e) => MapEntry(k as String, (e as num).toInt()),
  ),
  error: RumCount.fromJson(Map<String, dynamic>.from(json['error'] as Map)),
  flutterBuildTime: json['flutter_build_time'] == null
      ? null
      : RumPerformanceMetric.fromJson(
          Map<String, dynamic>.from(json['flutter_build_time'] as Map),
        ),
  flutterRasterTime: json['flutter_raster_time'] == null
      ? null
      : RumPerformanceMetric.fromJson(
          Map<String, dynamic>.from(json['flutter_raster_time'] as Map),
        ),
  frozenFrame: json['frozen_frame'] == null
      ? null
      : RumCount.fromJson(
          Map<String, dynamic>.from(json['frozen_frame'] as Map),
        ),
  frustration: json['frustration'] == null
      ? null
      : RumCount.fromJson(
          Map<String, dynamic>.from(json['frustration'] as Map),
        ),
  id: json['id'] as String,
  isActive: json['is_active'] as bool?,
  isSlowRendered: json['is_slow_rendered'] as bool?,
  longTask: json['long_task'] == null
      ? null
      : RumCount.fromJson(Map<String, dynamic>.from(json['long_task'] as Map)),
  memoryAverage: (json['memory_average'] as num?)?.toDouble(),
  memoryMax: (json['memory_max'] as num?)?.toDouble(),
  name: json['name'] as String?,
  referrer: json['referrer'] as String?,
  refreshRateAverage: (json['refresh_rate_average'] as num?)?.toDouble(),
  refreshRateMin: (json['refresh_rate_min'] as num?)?.toDouble(),
  resource: RumCount.fromJson(
    Map<String, dynamic>.from(json['resource'] as Map),
  ),
  timeSpent: (json['time_spent'] as num).toInt(),
  url: json['url'] as String,
);

Map<String, dynamic> _$RumViewDetailsToJson(RumViewDetails instance) =>
    <String, dynamic>{
      'action': instance.action.toJson(),
      'cpu_ticks_count': ?instance.cpuTicksCount,
      'cpu_ticks_per_second': ?instance.cpuTicksPerSecond,
      'crash': instance.crash.toJson(),
      'custom_timings': ?instance.customTimings,
      'error': instance.error.toJson(),
      'flutter_build_time': ?instance.flutterBuildTime?.toJson(),
      'flutter_raster_time': ?instance.flutterRasterTime?.toJson(),
      'frozen_frame': ?instance.frozenFrame?.toJson(),
      'frustration': ?instance.frustration?.toJson(),
      'id': instance.id,
      'is_active': ?instance.isActive,
      'is_slow_rendered': ?instance.isSlowRendered,
      'long_task': ?instance.longTask?.toJson(),
      'memory_average': ?instance.memoryAverage,
      'memory_max': ?instance.memoryMax,
      'name': ?instance.name,
      'referrer': ?instance.referrer,
      'refresh_rate_average': ?instance.refreshRateAverage,
      'refresh_rate_min': ?instance.refreshRateMin,
      'resource': instance.resource.toJson(),
      'time_spent': instance.timeSpent,
      'url': instance.url,
    };

RumCount _$RumCountFromJson(Map json) =>
    RumCount(count: (json['count'] as num).toInt());

Map<String, dynamic> _$RumCountToJson(RumCount instance) => <String, dynamic>{
  'count': instance.count,
};

RumPerformanceMetric _$RumPerformanceMetricFromJson(Map json) =>
    RumPerformanceMetric(
      average: (json['average'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
      metricMax: (json['metric_max'] as num?)?.toDouble(),
      min: (json['min'] as num).toDouble(),
    );

Map<String, dynamic> _$RumPerformanceMetricToJson(
  RumPerformanceMetric instance,
) => <String, dynamic>{
  'average': instance.average,
  'max': instance.max,
  'metric_max': ?instance.metricMax,
  'min': instance.min,
};

RumActionEvent _$RumActionEventFromJson(Map json) => RumActionEvent(
  action: RumAction.fromJson(Map<String, dynamic>.from(json['action'] as Map)),
  application: RumApplication.fromJson(
    Map<String, dynamic>.from(json['application'] as Map),
  ),
  connectivity: json['connectivity'] == null
      ? null
      : RumConnectivity.fromJson(
          Map<String, dynamic>.from(json['connectivity'] as Map),
        ),
  date: (json['date'] as num).toInt(),
  device: json['device'] == null
      ? null
      : RumDevice.fromJson(Map<String, dynamic>.from(json['device'] as Map)),
  os: json['os'] == null
      ? null
      : RumOperatingSystem.fromJson(
          Map<String, dynamic>.from(json['os'] as Map),
        ),
  service: json['service'] as String?,
  session: RumSession.fromJson(
    Map<String, dynamic>.from(json['session'] as Map),
  ),
  usr: json['usr'] == null
      ? null
      : RumUser.fromJson(Map<String, dynamic>.from(json['usr'] as Map)),
  version: json['version'] as String?,
  view: RumViewSummary.fromJson(Map<String, dynamic>.from(json['view'] as Map)),
  context: attributesFromJson(json['context'] as Map?),
);

Map<String, dynamic> _$RumActionEventToJson(RumActionEvent instance) =>
    <String, dynamic>{
      'action': instance.action.toJson(),
      'application': instance.application.toJson(),
      'connectivity': ?instance.connectivity?.toJson(),
      'date': instance.date,
      'device': ?instance.device?.toJson(),
      'os': ?instance.os?.toJson(),
      'service': ?instance.service,
      'session': instance.session.toJson(),
      'usr': ?instance.usr?.toJson(),
      'version': ?instance.version,
      'view': instance.view.toJson(),
      'context': instance.context,
    };

RumAction _$RumActionFromJson(Map json) => RumAction(
  crash: json['crash'] == null
      ? null
      : RumCount.fromJson(Map<String, dynamic>.from(json['crash'] as Map)),
  error: json['error'] == null
      ? null
      : RumCount.fromJson(Map<String, dynamic>.from(json['error'] as Map)),
  frustration: json['frustration'] == null
      ? null
      : RumActionFrustration.fromJson(
          Map<String, dynamic>.from(json['frustration'] as Map),
        ),
  id: json['id'] as String?,
  loadingTime: (json['loading_time'] as num?)?.toInt(),
  longTask: json['long_task'] == null
      ? null
      : RumCount.fromJson(Map<String, dynamic>.from(json['long_task'] as Map)),
  resource: json['resource'] == null
      ? null
      : RumCount.fromJson(Map<String, dynamic>.from(json['resource'] as Map)),
  target: json['target'] == null
      ? null
      : RumActionTarget.fromJson(
          Map<String, dynamic>.from(json['target'] as Map),
        ),
  type: $enumDecode(_$RumActionTypeInternalEnumMap, json['type']),
);

Map<String, dynamic> _$RumActionToJson(RumAction instance) => <String, dynamic>{
  'crash': ?instance.crash?.toJson(),
  'error': ?instance.error?.toJson(),
  'frustration': ?instance.frustration?.toJson(),
  'id': ?instance.id,
  'loading_time': ?instance.loadingTime,
  'long_task': ?instance.longTask?.toJson(),
  'resource': ?instance.resource?.toJson(),
  'target': ?instance.target?.toJson(),
  'type': _$RumActionTypeInternalEnumMap[instance.type]!,
};

const _$RumActionTypeInternalEnumMap = {
  RumActionTypeInternal.custom: 'custom',
  RumActionTypeInternal.click: 'click',
  RumActionTypeInternal.tap: 'tap',
  RumActionTypeInternal.scroll: 'scroll',
  RumActionTypeInternal.swipe: 'swipe',
  RumActionTypeInternal.applicationStart: 'application_start',
  RumActionTypeInternal.back: 'back',
};

RumActionTarget _$RumActionTargetFromJson(Map<String, dynamic> json) =>
    RumActionTarget(name: json['name'] as String);

Map<String, dynamic> _$RumActionTargetToJson(RumActionTarget instance) =>
    <String, dynamic>{'name': instance.name};

RumViewSummary _$RumViewSummaryFromJson(Map json) => RumViewSummary(
  id: json['id'] as String,
  inForeground: json['in_foreground'] as bool?,
  name: json['name'] as String?,
  referrer: json['referrer'] as String?,
  url: json['url'] as String,
);

Map<String, dynamic> _$RumViewSummaryToJson(RumViewSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'in_foreground': ?instance.inForeground,
      'name': ?instance.name,
      'referrer': ?instance.referrer,
      'url': instance.url,
    };

RumActionFrustration _$RumActionFrustrationFromJson(Map json) =>
    RumActionFrustration(
      type: (json['type'] as List<dynamic>)
          .map((e) => $enumDecode(_$RumFrustrationTypeEnumMap, e))
          .toList(),
    );

Map<String, dynamic> _$RumActionFrustrationToJson(
  RumActionFrustration instance,
) => <String, dynamic>{
  'type': instance.type.map((e) => _$RumFrustrationTypeEnumMap[e]!).toList(),
};

const _$RumFrustrationTypeEnumMap = {
  RumFrustrationType.rageClick: 'rage_click',
  RumFrustrationType.deadClick: 'dead_click',
  RumFrustrationType.errorClick: 'error_click',
  RumFrustrationType.rageTap: 'rage_tap',
  RumFrustrationType.errorTap: 'error_tap',
};

RumResource _$RumResourceFromJson(Map json) => RumResource(
  duration: (json['duration'] as num).toInt(),
  id: json['id'] as String?,
  method: json['method'] as String,
  size: (json['size'] as num?)?.toInt(),
  statusCode: (json['status_code'] as num?)?.toInt(),
  type: $enumDecode(_$RumResourceTypeEnumMap, json['type']),
  url: json['url'] as String,
);

Map<String, dynamic> _$RumResourceToJson(RumResource instance) =>
    <String, dynamic>{
      'duration': instance.duration,
      'id': ?instance.id,
      'method': instance.method,
      'size': ?instance.size,
      'status_code': ?instance.statusCode,
      'type': _$RumResourceTypeEnumMap[instance.type]!,
      'url': instance.url,
    };

const _$RumResourceTypeEnumMap = {
  RumResourceType.document: 'document',
  RumResourceType.image: 'image',
  RumResourceType.xhr: 'xhr',
  RumResourceType.beacon: 'beacon',
  RumResourceType.css: 'css',
  RumResourceType.fetch: 'fetch',
  RumResourceType.font: 'font',
  RumResourceType.js: 'js',
  RumResourceType.media: 'media',
  RumResourceType.other: 'other',
  RumResourceType.native: 'native',
};

RumResourceEvent _$RumResourceEventFromJson(Map json) => RumResourceEvent(
  action: json['action'] == null
      ? null
      : RumActionId.fromJson(Map<String, dynamic>.from(json['action'] as Map)),
  application: RumApplication.fromJson(
    Map<String, dynamic>.from(json['application'] as Map),
  ),
  connectivity: json['connectivity'] == null
      ? null
      : RumConnectivity.fromJson(
          Map<String, dynamic>.from(json['connectivity'] as Map),
        ),
  date: (json['date'] as num).toInt(),
  device: json['device'] == null
      ? null
      : RumDevice.fromJson(Map<String, dynamic>.from(json['device'] as Map)),
  os: json['os'] == null
      ? null
      : RumOperatingSystem.fromJson(
          Map<String, dynamic>.from(json['os'] as Map),
        ),
  service: json['service'] as String?,
  resource: RumResource.fromJson(
    Map<String, dynamic>.from(json['resource'] as Map),
  ),
  usr: json['usr'] == null
      ? null
      : RumUser.fromJson(Map<String, dynamic>.from(json['usr'] as Map)),
  version: json['version'] as String?,
  view: json['view'] == null
      ? null
      : RumViewSummary.fromJson(Map<String, dynamic>.from(json['view'] as Map)),
  context: attributesFromJson(json['context'] as Map?),
);

Map<String, dynamic> _$RumResourceEventToJson(RumResourceEvent instance) =>
    <String, dynamic>{
      'action': ?instance.action?.toJson(),
      'application': instance.application.toJson(),
      'connectivity': ?instance.connectivity?.toJson(),
      'date': instance.date,
      'device': ?instance.device?.toJson(),
      'os': ?instance.os?.toJson(),
      'resource': instance.resource.toJson(),
      'service': ?instance.service,
      'usr': ?instance.usr?.toJson(),
      'version': ?instance.version,
      'view': ?instance.view?.toJson(),
      'context': instance.context,
    };

RumErrorEvent _$RumErrorEventFromJson(Map json) => RumErrorEvent(
  action: json['action'] == null
      ? null
      : RumActionId.fromJson(Map<String, dynamic>.from(json['action'] as Map)),
  application: RumApplication.fromJson(
    Map<String, dynamic>.from(json['application'] as Map),
  ),
  connectivity: json['connectivity'] == null
      ? null
      : RumConnectivity.fromJson(
          Map<String, dynamic>.from(json['connectivity'] as Map),
        ),
  date: (json['date'] as num).toInt(),
  device: json['device'] == null
      ? null
      : RumDevice.fromJson(Map<String, dynamic>.from(json['device'] as Map)),
  error: RumError.fromJson(Map<String, dynamic>.from(json['error'] as Map)),
  os: json['os'] == null
      ? null
      : RumOperatingSystem.fromJson(
          Map<String, dynamic>.from(json['os'] as Map),
        ),
  service: json['service'] as String?,
  session: RumSession.fromJson(
    Map<String, dynamic>.from(json['session'] as Map),
  ),
  usr: json['usr'] == null
      ? null
      : RumUser.fromJson(Map<String, dynamic>.from(json['usr'] as Map)),
  version: json['version'] as String?,
  view: RumViewSummary.fromJson(Map<String, dynamic>.from(json['view'] as Map)),
  context: attributesFromJson(json['context'] as Map?),
);

Map<String, dynamic> _$RumErrorEventToJson(RumErrorEvent instance) =>
    <String, dynamic>{
      'action': ?instance.action?.toJson(),
      'application': instance.application.toJson(),
      'connectivity': ?instance.connectivity?.toJson(),
      'date': instance.date,
      'device': ?instance.device?.toJson(),
      'error': instance.error.toJson(),
      'os': ?instance.os?.toJson(),
      'service': ?instance.service,
      'session': instance.session.toJson(),
      'usr': ?instance.usr?.toJson(),
      'version': ?instance.version,
      'view': instance.view.toJson(),
      'context': instance.context,
    };

RumActionId _$RumActionIdFromJson(Map json) =>
    RumActionId(id: actionListFromJson(json['id']));

Map<String, dynamic> _$RumActionIdToJson(RumActionId instance) =>
    <String, dynamic>{'id': instance.id};

RumError _$RumErrorFromJson(Map json) => RumError(
  causes: (json['causes'] as List<dynamic>?)
      ?.map((e) => RumErrorCause.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  handling: $enumDecodeNullable(_$RumErrorHandlingEnumMap, json['handling']),
  handlingStack: json['handling_stack'] as String?,
  id: json['id'] as String?,
  isCrash: json['is_crash'] as bool?,
  message: json['message'] as String,
  resource: json['resource'] == null
      ? null
      : RumResourceSummary.fromJson(
          Map<String, dynamic>.from(json['resource'] as Map),
        ),
  source: $enumDecode(_$RumInternalErrorSourceEnumMap, json['source']),
  sourceType: json['source_type'] as String?,
  stack: json['stack'] as String?,
  type: json['type'] as String?,
  fingerprint: json['fingerprint'] as String?,
);

Map<String, dynamic> _$RumErrorToJson(RumError instance) => <String, dynamic>{
  'causes': ?instance.causes?.map((e) => e.toJson()).toList(),
  'handling': ?_$RumErrorHandlingEnumMap[instance.handling],
  'handling_stack': ?instance.handlingStack,
  'id': ?instance.id,
  'is_crash': ?instance.isCrash,
  'message': instance.message,
  'resource': ?instance.resource?.toJson(),
  'source': _$RumInternalErrorSourceEnumMap[instance.source]!,
  'source_type': ?instance.sourceType,
  'stack': ?instance.stack,
  'type': ?instance.type,
  'fingerprint': ?instance.fingerprint,
};

const _$RumErrorHandlingEnumMap = {
  RumErrorHandling.handled: 'handled',
  RumErrorHandling.unhandled: 'unhandled',
};

const _$RumInternalErrorSourceEnumMap = {
  RumInternalErrorSource.source: 'source',
  RumInternalErrorSource.network: 'network',
  RumInternalErrorSource.webview: 'webview',
  RumInternalErrorSource.console: 'console',
  RumInternalErrorSource.logger: 'logger',
  RumInternalErrorSource.agent: 'agent',
  RumInternalErrorSource.report: 'report',
  RumInternalErrorSource.custom: 'custom',
};

RumErrorCause _$RumErrorCauseFromJson(Map json) => RumErrorCause(
  message: json['message'] as String,
  source: $enumDecode(_$RumErrorSourceEnumMap, json['source']),
  stack: json['stack'] as String?,
  type: json['type'] as String?,
);

Map<String, dynamic> _$RumErrorCauseToJson(RumErrorCause instance) =>
    <String, dynamic>{
      'message': instance.message,
      'source': _$RumErrorSourceEnumMap[instance.source]!,
      'stack': ?instance.stack,
      'type': ?instance.type,
    };

const _$RumErrorSourceEnumMap = {
  RumErrorSource.source: 'source',
  RumErrorSource.network: 'network',
  RumErrorSource.webview: 'webview',
  RumErrorSource.console: 'console',
  RumErrorSource.custom: 'custom',
};

RumResourceSummary _$RumResourceSummaryFromJson(Map json) => RumResourceSummary(
  method: json['method'] as String,
  statusCode: (json['status_code'] as num).toInt(),
  url: json['url'] as String,
);

Map<String, dynamic> _$RumResourceSummaryToJson(RumResourceSummary instance) =>
    <String, dynamic>{
      'method': instance.method,
      'status_code': instance.statusCode,
      'url': instance.url,
    };

RumLongTaskEvent _$RumLongTaskEventFromJson(Map json) => RumLongTaskEvent(
  action: json['action'] == null
      ? null
      : RumActionId.fromJson(Map<String, dynamic>.from(json['action'] as Map)),
  application: RumApplication.fromJson(
    Map<String, dynamic>.from(json['application'] as Map),
  ),
  connectivity: json['connectivity'] == null
      ? null
      : RumConnectivity.fromJson(
          Map<String, dynamic>.from(json['connectivity'] as Map),
        ),
  date: (json['date'] as num).toInt(),
  device: json['device'] == null
      ? null
      : RumDevice.fromJson(Map<String, dynamic>.from(json['device'] as Map)),
  longTask: RumLongTask.fromJson(
    Map<String, dynamic>.from(json['long_task'] as Map),
  ),
  os: json['os'] == null
      ? null
      : RumOperatingSystem.fromJson(
          Map<String, dynamic>.from(json['os'] as Map),
        ),
  service: json['service'] as String?,
  session: RumSession.fromJson(
    Map<String, dynamic>.from(json['session'] as Map),
  ),
  usr: json['usr'] == null
      ? null
      : RumUser.fromJson(Map<String, dynamic>.from(json['usr'] as Map)),
  version: json['version'] as String?,
  view: RumViewSummary.fromJson(Map<String, dynamic>.from(json['view'] as Map)),
  context: attributesFromJson(json['context'] as Map?),
);

Map<String, dynamic> _$RumLongTaskEventToJson(RumLongTaskEvent instance) =>
    <String, dynamic>{
      'action': ?instance.action?.toJson(),
      'application': instance.application.toJson(),
      'connectivity': ?instance.connectivity?.toJson(),
      'date': instance.date,
      'device': ?instance.device?.toJson(),
      'long_task': instance.longTask.toJson(),
      'os': ?instance.os?.toJson(),
      'service': ?instance.service,
      'session': instance.session.toJson(),
      'usr': ?instance.usr?.toJson(),
      'version': ?instance.version,
      'view': instance.view.toJson(),
      'context': instance.context,
    };

RumLongTask _$RumLongTaskFromJson(Map json) => RumLongTask(
  duration: (json['duration'] as num).toInt(),
  id: json['id'] as String?,
  isFrozenFrame: json['is_frozen_frame'] as bool?,
);

Map<String, dynamic> _$RumLongTaskToJson(RumLongTask instance) =>
    <String, dynamic>{
      'duration': instance.duration,
      'id': ?instance.id,
      'is_frozen_frame': ?instance.isFrozenFrame,
    };

RumContainerView _$RumContainerViewFromJson(Map json) =>
    RumContainerView(id: json['id'] as String);

Map<String, dynamic> _$RumContainerViewToJson(RumContainerView instance) =>
    <String, dynamic>{'id': instance.id};

RumVitalOperationStepContainer _$RumVitalOperationStepContainerFromJson(
  Map json,
) => RumVitalOperationStepContainer(
  view: RumContainerView.fromJson(
    Map<String, dynamic>.from(json['view'] as Map),
  ),
);

Map<String, dynamic> _$RumVitalOperationStepContainerToJson(
  RumVitalOperationStepContainer instance,
) => <String, dynamic>{'view': instance.view.toJson()};

RumVital _$RumVitalFromJson(Map json) => RumVital(
  id: json['id'] as String,
  name: json['name'] as String?,
  description: json['description'] as String?,
  operationKey: json['operation_key'] as String?,
  stepType: json['step_type'] as String,
  failureReason: json['failure_reason'] as String,
);

Map<String, dynamic> _$RumVitalToJson(RumVital instance) => <String, dynamic>{
  'id': instance.id,
  'name': ?instance.name,
  'description': ?instance.description,
  'operation_key': ?instance.operationKey,
  'step_type': instance.stepType,
  'failure_reason': instance.failureReason,
};

RumVitalOperationStepEvent _$RumVitalOperationStepEventFromJson(
  Map json,
) => RumVitalOperationStepEvent(
  application: RumApplication.fromJson(
    Map<String, dynamic>.from(json['application'] as Map),
  ),
  buildVersion: json['build_version'] as String?,
  buildId: json['build_id'] as String?,
  connectivity: json['connectivity'] == null
      ? null
      : RumConnectivity.fromJson(
          Map<String, dynamic>.from(json['connectivity'] as Map),
        ),
  container: json['container'] == null
      ? null
      : RumVitalOperationStepContainer.fromJson(
          Map<String, dynamic>.from(json['container'] as Map),
        ),
  date: (json['date'] as num).toInt(),
  ddtags: json['ddtags'] as String?,
  device: json['device'] == null
      ? null
      : RumDevice.fromJson(Map<String, dynamic>.from(json['device'] as Map)),
  os: json['os'] == null
      ? null
      : RumOperatingSystem.fromJson(
          Map<String, dynamic>.from(json['os'] as Map),
        ),
  service: json['service'] as String?,
  session: RumSession.fromJson(
    Map<String, dynamic>.from(json['session'] as Map),
  ),
  usr: json['usr'] == null
      ? null
      : RumUser.fromJson(Map<String, dynamic>.from(json['usr'] as Map)),
  version: json['version'] as String?,
  view: RumViewSummary.fromJson(Map<String, dynamic>.from(json['view'] as Map)),
  vital: RumVital.fromJson(Map<String, dynamic>.from(json['vital'] as Map)),
  context: attributesFromJson(json['context'] as Map?),
);

Map<String, dynamic> _$RumVitalOperationStepEventToJson(
  RumVitalOperationStepEvent instance,
) => <String, dynamic>{
  'application': instance.application.toJson(),
  'build_version': ?instance.buildVersion,
  'build_id': ?instance.buildId,
  'connectivity': ?instance.connectivity?.toJson(),
  'container': ?instance.container?.toJson(),
  'date': instance.date,
  'ddtags': ?instance.ddtags,
  'device': ?instance.device?.toJson(),
  'os': ?instance.os?.toJson(),
  'service': ?instance.service,
  'session': instance.session.toJson(),
  'usr': ?instance.usr?.toJson(),
  'version': ?instance.version,
  'view': instance.view.toJson(),
  'vital': instance.vital.toJson(),
  'context': instance.context,
};
