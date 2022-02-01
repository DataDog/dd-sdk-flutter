class TestingConfiguration {
  String? customEndpoint;
  String? clientToken;
  String? applicationId;
  List<String> firstPartyHosts;

  TestingConfiguration({
    this.customEndpoint,
    this.clientToken,
    this.applicationId,
    this.firstPartyHosts = const [],
  });
}
