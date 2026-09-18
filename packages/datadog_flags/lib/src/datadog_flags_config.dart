// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:meta/meta.dart';

/// Datadog site used for feature flag assignment and telemetry endpoints.
enum DatadogFlagsSite {
  /// Datadog US1 production site.
  us1(
    'https://preview.ff-cdn.datadoghq.com',
    'https://browser-intake-datadoghq.com',
  ),

  /// Datadog US1 staging site.
  us1Staging(
    'https://preview.ff-cdn.datad0g.com',
    'https://browser-intake-datad0g.com',
  ),

  /// Datadog US3 production site.
  us3(
    'https://preview.ff-cdn.us3.datadoghq.com',
    'https://browser-intake-us3-datadoghq.com',
  ),

  /// Datadog US5 production site.
  us5(
    'https://preview.ff-cdn.us5.datadoghq.com',
    'https://browser-intake-us5-datadoghq.com',
  ),

  /// Datadog EU1 production site.
  eu1(
    'https://preview.ff-cdn.datadoghq.eu',
    'https://browser-intake-datadoghq.eu',
  ),

  /// Datadog AP1 production site.
  ap1(
    'https://preview.ff-cdn.ap1.datadoghq.com',
    'https://browser-intake-ap1-datadoghq.com',
  ),

  /// Datadog AP2 production site.
  ap2(
    'https://preview.ff-cdn.ap2.datadoghq.com',
    'https://browser-intake-ap2-datadoghq.com',
  );

  /// Base URL for precompute assignment requests.
  final String flagsEndpointUrl;

  /// Base URL for exposure and flag evaluation intake.
  final String intakeEndpointUrl;

  /// Creates a Datadog site from endpoint URLs.
  const DatadogFlagsSite(this.flagsEndpointUrl, this.intakeEndpointUrl);

  /// Parsed precompute assignment endpoint.
  Uri get flagsEndpoint => Uri.parse(flagsEndpointUrl);

  /// Parsed telemetry intake endpoint.
  Uri get intakeEndpoint => Uri.parse(intakeEndpointUrl);
}

/// Datadog account and application metadata used by the Flags SDK.
@immutable
final class DatadogFlagsConfig {
  /// Public client token for the Datadog organization.
  final String clientToken;

  /// Datadog environment name used for assignment requests.
  final String env;

  /// Datadog site that receives assignments and telemetry.
  final DatadogFlagsSite site;

  /// Optional RUM application id used to associate telemetry with an app.
  final String? applicationId;

  /// Optional service name attached to telemetry.
  final String? service;

  /// Optional application version attached to telemetry.
  final String? version;

  /// Creates Datadog account and application metadata for feature flags.
  const DatadogFlagsConfig({
    required this.clientToken,
    required this.env,
    required this.site,
    this.applicationId,
    this.service,
    this.version,
  });

  /// Returns the precompute assignment endpoint for [site].
  Uri flagsEndpoint() => site.flagsEndpoint;

  /// Returns the telemetry intake endpoint for [site].
  Uri intakeEndpoint() => site.intakeEndpoint;
}
