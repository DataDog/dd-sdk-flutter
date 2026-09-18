// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ddrum_events.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RumViewEvent _$RumViewEventFromJson(Map json) => RumViewEvent(
      dd: RumViewEventDd.fromJson(
          Map<String, dynamic>.from(json['_dd'] as Map)),
      application: RumApplication.fromJson(
          Map<String, dynamic>.from(json['application'] as Map)),
      connectivity: json['connectivity'] == null
          ? null
          : RumConnectivity.fromJson(
              Map<String, dynamic>.from(json['connectivity'] as Map)),
      context: attributesFromJson(json['context'] as Map?),
      date: (json['date'] as num).toInt(),
      device: json['device'] == null
          ? null
          : RumDevice.fromJson(
              Map<String, dynamic>.from(json['device'] as Map)),
      os: json['os'] == null
          ? null
          : RumOperatingSystem.fromJson(
              Map<String, dynamic>.from(json['os'] as Map)),
      service: json['service'] as String,
      session: RumSession.fromJson(
          Map<String, dynamic>.from(json['session'] as Map)),
      usr: json['usr'] == null
          ? null
          : RumUser.fromJson(Map<String, dynamic>.from(json['usr'] as Map)),
      version: json['version'] as String,
      view: RumViewDetails.fromJson(
          Map<String, dynamic>.from(json['view'] as Map)),
    );

Map<String, dynamic> _$RumViewEventToJson(RumViewEvent instance) =>
    <String, dynamic>{
      '_dd': instance.dd.toJson(),
      'application': instance.application.toJson(),
      if (instance.connectivity?.toJson() case final value?)
        'connectivity': value,
      'context': instance.context,
      'date': instance.date,
      if (instance.device?.toJson() case final value?) 'device': value,
      if (instance.os?.toJson() case final value?) 'os': value,
      'service': instance.service,
      'session': instance.session.toJson(),
      if (instance.usr?.toJson() case final value?) 'usr': value,
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

RumApplication _$RumApplicationFromJson(Map json) => RumApplication(
      id: json['id'] as String,
    );

Map<String, dynamic> _$RumApplicationToJson(RumApplication instance) =>
    <String, dynamic>{
      'id': instance.id,
    };

RumConnectivity _$RumConnectivityFromJson(Map json) => RumConnectivity(
      cellular: json['cellular'] == null
          ? null
          : RumCellular.fromJson(
              Map<String, dynamic>.from(json['cellular'] as Map)),
      interfaces: (json['interfaces'] as List<dynamic>)
          .map((e) => $enumDecode(_$RumConnectivityInterfacesEnumMap, e))
          .toList(),
      status: $enumDecode(_$RumConnectivityStatusEnumMap, json['status']),
    );

Map<String, dynamic> _$RumConnectivityToJson(RumConnectivity instance) =>
    <String, dynamic>{
      if (instance.cellular?.toJson() case final value?) 'cellular': value,
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
      if (instance.hasReplay case final value?) 'has_replay': value,
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
      if (instance.architecture case final value?) 'architecture': value,
      if (instance.brand case final value?) 'brand': value,
      if (instance.model case final value?) 'model': value,
      if (instance.name case final value?) 'name': value,
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
      if (instance.email case final value?) 'email': value,
      if (instance.id case final value?) 'id': value,
      if (instance.name case final value?) 'name': value,
      'usr_info': instance.usrInfo,
    };

RumViewDetails _$RumViewDetailsFromJson(Map json) => RumViewDetails(
      action:
          RumCount.fromJson(Map<String, dynamic>.from(json['action'] as Map)),
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
              Map<String, dynamic>.from(json['flutter_build_time'] as Map)),
      flutterRasterTime: json['flutter_raster_time'] == null
          ? null
          : RumPerformanceMetric.fromJson(
              Map<String, dynamic>.from(json['flutter_raster_time'] as Map)),
      frozenFrame: json['frozen_frame'] == null
          ? null
          : RumCount.fromJson(
              Map<String, dynamic>.from(json['frozen_frame'] as Map)),
      frustration: json['frustration'] == null
          ? null
          : RumCount.fromJson(
              Map<String, dynamic>.from(json['frustration'] as Map)),
      id: json['id'] as String,
      isActive: json['is_active'] as bool?,
      isSlowRendered: json['is_slow_rendered'] as bool?,
      longTask: json['long_task'] == null
          ? null
          : RumCount.fromJson(
              Map<String, dynamic>.from(json['long_task'] as Map)),
      memoryAverage: (json['memory_average'] as num?)?.toDouble(),
      memoryMax: (json['memory_max'] as num?)?.toDouble(),
      name: json['name'] as String?,
      referrer: json['referrer'] as String?,
      refreshRateAverage: (json['refresh_rate_average'] as num?)?.toDouble(),
      refreshRateMin: (json['refresh_rate_min'] as num?)?.toDouble(),
      resource:
          RumCount.fromJson(Map<String, dynamic>.from(json['resource'] as Map)),
      timeSpent: (json['time_spent'] as num).toInt(),
      url: json['url'] as String,
    );

Map<String, dynamic> _$RumViewDetailsToJson(RumViewDetails instance) =>
    <String, dynamic>{
      'action': instance.action.toJson(),
      if (instance.cpuTicksCount case final value?) 'cpu_ticks_count': value,
      if (instance.cpuTicksPerSecond case final value?)
        'cpu_ticks_per_second': value,
      'crash': instance.crash.toJson(),
      if (instance.customTimings case final value?) 'custom_timings': value,
      'error': instance.error.toJson(),
      if (instance.flutterBuildTime?.toJson() case final value?)
        'flutter_build_time': value,
      if (instance.flutterRasterTime?.toJson() case final value?)
        'flutter_raster_time': value,
      if (instance.frozenFrame?.toJson() case final value?)
        'frozen_frame': value,
      if (instance.frustration?.toJson() case final value?)
        'frustration': value,
      'id': instance.id,
      if (instance.isActive case final value?) 'is_active': value,
      if (instance.isSlowRendered case final value?) 'is_slow_rendered': value,
      if (instance.longTask?.toJson() case final value?) 'long_task': value,
      if (instance.memoryAverage case final value?) 'memory_average': value,
      if (instance.memoryMax case final value?) 'memory_max': value,
      if (instance.name case final value?) 'name': value,
      if (instance.referrer case final value?) 'referrer': value,
      if (instance.refreshRateAverage case final value?)
        'refresh_rate_average': value,
      if (instance.refreshRateMin case final value?) 'refresh_rate_min': value,
      'resource': instance.resource.toJson(),
      'time_spent': instance.timeSpent,
      'url': instance.url,
    };

RumCount _$RumCountFromJson(Map json) => RumCount(
      count: (json['count'] as num).toInt(),
    );

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
        RumPerformanceMetric instance) =>
    <String, dynamic>{
      'average': instance.average,
      'max': instance.max,
      if (instance.metricMax case final value?) 'metric_max': value,
      'min': instance.min,
    };

RumActionEvent _$RumActionEventFromJson(Map json) => RumActionEvent(
      action:
          RumAction.fromJson(Map<String, dynamic>.from(json['action'] as Map)),
      application: RumApplication.fromJson(
          Map<String, dynamic>.from(json['application'] as Map)),
      connectivity: json['connectivity'] == null
          ? null
          : RumConnectivity.fromJson(
              Map<String, dynamic>.from(json['connectivity'] as Map)),
      date: (json['date'] as num).toInt(),
      device: json['device'] == null
          ? null
          : RumDevice.fromJson(
              Map<String, dynamic>.from(json['device'] as Map)),
      os: json['os'] == null
          ? null
          : RumOperatingSystem.fromJson(
              Map<String, dynamic>.from(json['os'] as Map)),
      service: json['service'] as String?,
      session: RumSession.fromJson(
          Map<String, dynamic>.from(json['session'] as Map)),
      usr: json['usr'] == null
          ? null
          : RumUser.fromJson(Map<String, dynamic>.from(json['usr'] as Map)),
      version: json['version'] as String?,
      view: RumViewSummary.fromJson(
          Map<String, dynamic>.from(json['view'] as Map)),
      context: attributesFromJson(json['context'] as Map?),
    );

Map<String, dynamic> _$RumActionEventToJson(RumActionEvent instance) =>
    <String, dynamic>{
      'action': instance.action.toJson(),
      'application': instance.application.toJson(),
      if (instance.connectivity?.toJson() case final value?)
        'connectivity': value,
      'date': instance.date,
      if (instance.device?.toJson() case final value?) 'device': value,
      if (instance.os?.toJson() case final value?) 'os': value,
      if (instance.service case final value?) 'service': value,
      'session': instance.session.toJson(),
      if (instance.usr?.toJson() case final value?) 'usr': value,
      if (instance.version case final value?) 'version': value,
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
              Map<String, dynamic>.from(json['frustration'] as Map)),
      id: json['id'] as String?,
      loadingTime: (json['loading_time'] as num?)?.toInt(),
      longTask: json['long_task'] == null
          ? null
          : RumCount.fromJson(
              Map<String, dynamic>.from(json['long_task'] as Map)),
      resource: json['resource'] == null
          ? null
          : RumCount.fromJson(
              Map<String, dynamic>.from(json['resource'] as Map)),
      target: json['target'] == null
          ? null
          : RumActionTarget.fromJson(
              Map<String, dynamic>.from(json['target'] as Map)),
      type: $enumDecode(_$RumActionTypeInternalEnumMap, json['type']),
    );

Map<String, dynamic> _$RumActionToJson(RumAction instance) => <String, dynamic>{
      if (instance.crash?.toJson() case final value?) 'crash': value,
      if (instance.error?.toJson() case final value?) 'error': value,
      if (instance.frustration?.toJson() case final value?)
        'frustration': value,
      if (instance.id case final value?) 'id': value,
      if (instance.loadingTime case final value?) 'loading_time': value,
      if (instance.longTask?.toJson() case final value?) 'long_task': value,
      if (instance.resource?.toJson() case final value?) 'resource': value,
      if (instance.target?.toJson() case final value?) 'target': value,
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
    RumActionTarget(
      name: json['name'] as String,
    );

Map<String, dynamic> _$RumActionTargetToJson(RumActionTarget instance) =>
    <String, dynamic>{
      'name': instance.name,
    };

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
      if (instance.inForeground case final value?) 'in_foreground': value,
      if (instance.name case final value?) 'name': value,
      if (instance.referrer case final value?) 'referrer': value,
      'url': instance.url,
    };

RumActionFrustration _$RumActionFrustrationFromJson(Map json) =>
    RumActionFrustration(
      type: (json['type'] as List<dynamic>)
          .map((e) => $enumDecode(_$RumFrustrationTypeEnumMap, e))
          .toList(),
    );

Map<String, dynamic> _$RumActionFrustrationToJson(
        RumActionFrustration instance) =>
    <String, dynamic>{
      'type':
          instance.type.map((e) => _$RumFrustrationTypeEnumMap[e]!).toList(),
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
      if (instance.id case final value?) 'id': value,
      'method': instance.method,
      if (instance.size case final value?) 'size': value,
      if (instance.statusCode case final value?) 'status_code': value,
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
          : RumActionId.fromJson(
              Map<String, dynamic>.from(json['action'] as Map)),
      application: RumApplication.fromJson(
          Map<String, dynamic>.from(json['application'] as Map)),
      connectivity: json['connectivity'] == null
          ? null
          : RumConnectivity.fromJson(
              Map<String, dynamic>.from(json['connectivity'] as Map)),
      date: (json['date'] as num).toInt(),
      device: json['device'] == null
          ? null
          : RumDevice.fromJson(
              Map<String, dynamic>.from(json['device'] as Map)),
      os: json['os'] == null
          ? null
          : RumOperatingSystem.fromJson(
              Map<String, dynamic>.from(json['os'] as Map)),
      service: json['service'] as String?,
      resource: RumResource.fromJson(
          Map<String, dynamic>.from(json['resource'] as Map)),
      usr: json['usr'] == null
          ? null
          : RumUser.fromJson(Map<String, dynamic>.from(json['usr'] as Map)),
      version: json['version'] as String?,
      view: json['view'] == null
          ? null
          : RumViewSummary.fromJson(
              Map<String, dynamic>.from(json['view'] as Map)),
      context: attributesFromJson(json['context'] as Map?),
    );

Map<String, dynamic> _$RumResourceEventToJson(RumResourceEvent instance) =>
    <String, dynamic>{
      if (instance.action?.toJson() case final value?) 'action': value,
      'application': instance.application.toJson(),
      if (instance.connectivity?.toJson() case final value?)
        'connectivity': value,
      'date': instance.date,
      if (instance.device?.toJson() case final value?) 'device': value,
      if (instance.os?.toJson() case final value?) 'os': value,
      'resource': instance.resource.toJson(),
      if (instance.service case final value?) 'service': value,
      if (instance.usr?.toJson() case final value?) 'usr': value,
      if (instance.version case final value?) 'version': value,
      if (instance.view?.toJson() case final value?) 'view': value,
      'context': instance.context,
    };

RumErrorEvent _$RumErrorEventFromJson(Map json) => RumErrorEvent(
      action: json['action'] == null
          ? null
          : RumActionId.fromJson(
              Map<String, dynamic>.from(json['action'] as Map)),
      application: RumApplication.fromJson(
          Map<String, dynamic>.from(json['application'] as Map)),
      connectivity: json['connectivity'] == null
          ? null
          : RumConnectivity.fromJson(
              Map<String, dynamic>.from(json['connectivity'] as Map)),
      date: (json['date'] as num).toInt(),
      device: json['device'] == null
          ? null
          : RumDevice.fromJson(
              Map<String, dynamic>.from(json['device'] as Map)),
      error: RumError.fromJson(Map<String, dynamic>.from(json['error'] as Map)),
      os: json['os'] == null
          ? null
          : RumOperatingSystem.fromJson(
              Map<String, dynamic>.from(json['os'] as Map)),
      service: json['service'] as String?,
      session: RumSession.fromJson(
          Map<String, dynamic>.from(json['session'] as Map)),
      usr: json['usr'] == null
          ? null
          : RumUser.fromJson(Map<String, dynamic>.from(json['usr'] as Map)),
      version: json['version'] as String?,
      view: RumViewSummary.fromJson(
          Map<String, dynamic>.from(json['view'] as Map)),
      context: attributesFromJson(json['context'] as Map?),
    );

Map<String, dynamic> _$RumErrorEventToJson(RumErrorEvent instance) =>
    <String, dynamic>{
      if (instance.action?.toJson() case final value?) 'action': value,
      'application': instance.application.toJson(),
      if (instance.connectivity?.toJson() case final value?)
        'connectivity': value,
      'date': instance.date,
      if (instance.device?.toJson() case final value?) 'device': value,
      'error': instance.error.toJson(),
      if (instance.os?.toJson() case final value?) 'os': value,
      if (instance.service case final value?) 'service': value,
      'session': instance.session.toJson(),
      if (instance.usr?.toJson() case final value?) 'usr': value,
      if (instance.version case final value?) 'version': value,
      'view': instance.view.toJson(),
      'context': instance.context,
    };

RumActionId _$RumActionIdFromJson(Map json) => RumActionId(
      id: actionListFromJson(json['id']),
    );

Map<String, dynamic> _$RumActionIdToJson(RumActionId instance) =>
    <String, dynamic>{
      'id': instance.id,
    };

RumError _$RumErrorFromJson(Map json) => RumError(
      causes: (json['causes'] as List<dynamic>?)
          ?.map((e) =>
              RumErrorCause.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      handling:
          $enumDecodeNullable(_$RumErrorHandlingEnumMap, json['handling']),
      handlingStack: json['handling_stack'] as String?,
      id: json['id'] as String?,
      isCrash: json['is_crash'] as bool?,
      message: json['message'] as String,
      resource: json['resource'] == null
          ? null
          : RumResourceSummary.fromJson(
              Map<String, dynamic>.from(json['resource'] as Map)),
      source: $enumDecode(_$RumInternalErrorSourceEnumMap, json['source']),
      sourceType: json['source_type'] as String?,
      stack: json['stack'] as String?,
      type: json['type'] as String?,
      fingerprint: json['fingerprint'] as String?,
    );

Map<String, dynamic> _$RumErrorToJson(RumError instance) => <String, dynamic>{
      if (instance.causes?.map((e) => e.toJson()).toList() case final value?)
        'causes': value,
      if (_$RumErrorHandlingEnumMap[instance.handling] case final value?)
        'handling': value,
      if (instance.handlingStack case final value?) 'handling_stack': value,
      if (instance.id case final value?) 'id': value,
      if (instance.isCrash case final value?) 'is_crash': value,
      'message': instance.message,
      if (instance.resource?.toJson() case final value?) 'resource': value,
      'source': _$RumInternalErrorSourceEnumMap[instance.source]!,
      if (instance.sourceType case final value?) 'source_type': value,
      if (instance.stack case final value?) 'stack': value,
      if (instance.type case final value?) 'type': value,
      if (instance.fingerprint case final value?) 'fingerprint': value,
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
      if (instance.stack case final value?) 'stack': value,
      if (instance.type case final value?) 'type': value,
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
          : RumActionId.fromJson(
              Map<String, dynamic>.from(json['action'] as Map)),
      application: RumApplication.fromJson(
          Map<String, dynamic>.from(json['application'] as Map)),
      connectivity: json['connectivity'] == null
          ? null
          : RumConnectivity.fromJson(
              Map<String, dynamic>.from(json['connectivity'] as Map)),
      date: (json['date'] as num).toInt(),
      device: json['device'] == null
          ? null
          : RumDevice.fromJson(
              Map<String, dynamic>.from(json['device'] as Map)),
      longTask: RumLongTask.fromJson(
          Map<String, dynamic>.from(json['long_task'] as Map)),
      os: json['os'] == null
          ? null
          : RumOperatingSystem.fromJson(
              Map<String, dynamic>.from(json['os'] as Map)),
      service: json['service'] as String?,
      session: RumSession.fromJson(
          Map<String, dynamic>.from(json['session'] as Map)),
      usr: json['usr'] == null
          ? null
          : RumUser.fromJson(Map<String, dynamic>.from(json['usr'] as Map)),
      version: json['version'] as String?,
      view: RumViewSummary.fromJson(
          Map<String, dynamic>.from(json['view'] as Map)),
      context: attributesFromJson(json['context'] as Map?),
    );

Map<String, dynamic> _$RumLongTaskEventToJson(RumLongTaskEvent instance) =>
    <String, dynamic>{
      if (instance.action?.toJson() case final value?) 'action': value,
      'application': instance.application.toJson(),
      if (instance.connectivity?.toJson() case final value?)
        'connectivity': value,
      'date': instance.date,
      if (instance.device?.toJson() case final value?) 'device': value,
      'long_task': instance.longTask.toJson(),
      if (instance.os?.toJson() case final value?) 'os': value,
      if (instance.service case final value?) 'service': value,
      'session': instance.session.toJson(),
      if (instance.usr?.toJson() case final value?) 'usr': value,
      if (instance.version case final value?) 'version': value,
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
      if (instance.id case final value?) 'id': value,
      if (instance.isFrozenFrame case final value?) 'is_frozen_frame': value,
    };

RumContainerView _$RumContainerViewFromJson(Map json) => RumContainerView(
      id: json['id'] as String,
    );

Map<String, dynamic> _$RumContainerViewToJson(RumContainerView instance) =>
    <String, dynamic>{
      'id': instance.id,
    };

RumVitalOperationStepContainer _$RumVitalOperationStepContainerFromJson(
        Map json) =>
    RumVitalOperationStepContainer(
      view: RumContainerView.fromJson(
          Map<String, dynamic>.from(json['view'] as Map)),
    );

Map<String, dynamic> _$RumVitalOperationStepContainerToJson(
        RumVitalOperationStepContainer instance) =>
    <String, dynamic>{
      'view': instance.view.toJson(),
    };

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
      if (instance.name case final value?) 'name': value,
      if (instance.description case final value?) 'description': value,
      if (instance.operationKey case final value?) 'operation_key': value,
      'step_type': instance.stepType,
      'failure_reason': instance.failureReason,
    };

RumVitalOperationStepEvent _$RumVitalOperationStepEventFromJson(Map json) =>
    RumVitalOperationStepEvent(
      application: RumApplication.fromJson(
          Map<String, dynamic>.from(json['application'] as Map)),
      buildVersion: json['build_version'] as String?,
      buildId: json['build_id'] as String?,
      connectivity: json['connectivity'] == null
          ? null
          : RumConnectivity.fromJson(
              Map<String, dynamic>.from(json['connectivity'] as Map)),
      container: json['container'] == null
          ? null
          : RumVitalOperationStepContainer.fromJson(
              Map<String, dynamic>.from(json['container'] as Map)),
      date: (json['date'] as num).toInt(),
      ddtags: json['ddtags'] as String?,
      device: json['device'] == null
          ? null
          : RumDevice.fromJson(
              Map<String, dynamic>.from(json['device'] as Map)),
      os: json['os'] == null
          ? null
          : RumOperatingSystem.fromJson(
              Map<String, dynamic>.from(json['os'] as Map)),
      service: json['service'] as String?,
      session: RumSession.fromJson(
          Map<String, dynamic>.from(json['session'] as Map)),
      usr: json['usr'] == null
          ? null
          : RumUser.fromJson(Map<String, dynamic>.from(json['usr'] as Map)),
      version: json['version'] as String?,
      view: RumViewSummary.fromJson(
          Map<String, dynamic>.from(json['view'] as Map)),
      vital: RumVital.fromJson(Map<String, dynamic>.from(json['vital'] as Map)),
      context: attributesFromJson(json['context'] as Map?),
    );

Map<String, dynamic> _$RumVitalOperationStepEventToJson(
        RumVitalOperationStepEvent instance) =>
    <String, dynamic>{
      'application': instance.application.toJson(),
      if (instance.buildVersion case final value?) 'build_version': value,
      if (instance.buildId case final value?) 'build_id': value,
      if (instance.connectivity?.toJson() case final value?)
        'connectivity': value,
      if (instance.container?.toJson() case final value?) 'container': value,
      'date': instance.date,
      if (instance.ddtags case final value?) 'ddtags': value,
      if (instance.device?.toJson() case final value?) 'device': value,
      if (instance.os?.toJson() case final value?) 'os': value,
      if (instance.service case final value?) 'service': value,
      'session': instance.session.toJson(),
      if (instance.usr?.toJson() case final value?) 'usr': value,
      if (instance.version case final value?) 'version': value,
      'view': instance.view.toJson(),
      'vital': instance.vital.toJson(),
      'context': instance.context,
    };
