// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

class TestingConfiguration {
  String? scenario;
  String? customEndpoint;
  String? clientToken;
  String? applicationId;
  List<String> firstPartyHosts;
  Map<String, Object?> additionalConfig;

  TestingConfiguration({
    this.scenario,
    this.customEndpoint,
    this.clientToken,
    this.applicationId,
    this.firstPartyHosts = const [],
    this.additionalConfig = const {},
  });
}
