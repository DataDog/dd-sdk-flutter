// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

class RumAutoInstrumentationScenarioConfig {
  final List<String> firstPartyHosts;
  final String firstPartyGetUrl;
  final String? firstPartyPostUrl;
  final String firstPartyBadUrl;
  final String thirdPartyGetUrl;
  final String thirdPartyPostUrl;

  RumAutoInstrumentationScenarioConfig({
    this.firstPartyHosts = const ['foo.bar'],
    this.firstPartyGetUrl = 'https://status.datadoghq.com',
    this.firstPartyPostUrl,
    this.firstPartyBadUrl = 'https://foo.bar',
    this.thirdPartyGetUrl = 'https://httpbingo.org/get',
    this.thirdPartyPostUrl = 'https://httpbingo.org/post',
  });

  static RumAutoInstrumentationScenarioConfig? _instance;
  static RumAutoInstrumentationScenarioConfig get instance {
    _instance ??= RumAutoInstrumentationScenarioConfig();
    return _instance!;
  }

  static set instance(RumAutoInstrumentationScenarioConfig value) =>
      _instance = value;
}
