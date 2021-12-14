// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

class LogKeys {
  static const date = 'date';
  static const status = 'status';

  static const message = 'message';
  static const serviceName = 'service';
  static const tags = 'ddtags';

  static const applicationVersion = 'version';

  static const loggerName = 'logger.name';
  static const loggerVersion = 'logger.version';
  static const threadName = 'logger.thread_name';

  static const userId = 'usr.id';
  static const userName = 'usr.name';
  static const userEmail = 'usr.email';

  static const networkReachability = 'network.client.reachability';
  static const networkAvailableInterfaces =
      'network.client.available_interfaces';
  static const networkConnectionSupportsIPv4 = 'network.client.supports_ipv4';
  static const networkConnectionSupportsIPv6 = 'network.client.supports_ipv6';
  static const networkConnectionIsExpensive = 'network.client.is_expensive';
  static const networkConnectionIsConstrained = 'network.client.is_constrained';

  static const mobileNetworkCarrierName = 'network.client.sim_carrier.name';
  static const mobileNetworkCarrierISOCountryCode =
      'network.client.sim_carrier.iso_country';
  static const mobileNetworkCarrierRadioTechnology =
      'network.client.sim_carrier.technology';
  static const mobileNetworkCarrierAllowsVoIP =
      'network.client.sim_carrier.allows_voip';

  static const errorKind = 'error.kind';
  static const errorMessage = 'error.message';
  static const errorStack = 'error.stack';
}
