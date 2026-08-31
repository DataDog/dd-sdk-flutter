// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
class RumAutoInstrumentationScenarioConfig {
  final List<String> imageUrls;
  final List<String> firstPartyHosts;
  final String firstPartyGetUrl;
  final String? firstPartyPostUrl;
  final String firstPartyBadUrl;
  final String thirdPartyGetUrl;
  final String thirdPartyPostUrl;
  final String thirdPartyMissingUrl;

  RumAutoInstrumentationScenarioConfig({
    this.imageUrls = const [
      'https://picsum.photos/200',
      'https://placehold.co/200x200.png',
    ],
    this.firstPartyHosts = const ['foo.bar'],
    this.firstPartyGetUrl = 'https://status.datadoghq.com',
    this.firstPartyPostUrl,
    this.firstPartyBadUrl = 'https://foo.bar',
    this.thirdPartyGetUrl = 'https://httpbingo.org/get',
    this.thirdPartyPostUrl = 'https://httpbingo.org/post',
    this.thirdPartyMissingUrl = 'https://httpbingo.org/status/404',
  });

  static RumAutoInstrumentationScenarioConfig? _instance;
  static RumAutoInstrumentationScenarioConfig get instance {
    _instance ??= RumAutoInstrumentationScenarioConfig();
    return _instance!;
  }

  static set instance(RumAutoInstrumentationScenarioConfig value) =>
      _instance = value;
}
