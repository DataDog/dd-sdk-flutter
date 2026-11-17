// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// Legacy API coverage until the next major release.
// ignore_for_file: deprecated_member_use_from_same_package

@TestOn('browser')
library;

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/flag_assignments_fetcher.dart';
import 'package:datadog_flags/src/flags_error.dart';
import 'package:datadog_flags/src/response_protection.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'tls_test_certificates.dart';

void main() {
  const datadogConfig = DatadogFlagsConfig(
    clientToken: 'client-token',
    env: 'test',
    site: DatadogFlagsSite.us1,
  );
  final configuration = DatadogFlagsConfiguration(
    datadogConfig: datadogConfig,
    responseProtection: ResponseProtection.tlsPinning(
      mode: ResponseProtectionMode.required,
      profile: TlsPinningProfile(
        name: 'test',
        hosts: {DatadogFlagsSite.us1.flagsEndpoint.host},
        spkiSha256Pins: {leafAEcSpkiPin, leafBRsaSpkiPin},
      ),
    ),
    trackExposures: false,
    trackEvaluations: false,
  );

  final stagingEndpoint = Uri.parse(
    'https://protected.ff-cdn.datad0g.com/precompute-assignments',
  );
  final profiles = {
    'leaf': (configuration, DatadogFlagsSite.us1.flagsEndpoint),
    'issuer': (
      DatadogFlagsConfiguration(
        datadogConfig: datadogConfig,
        customFlagsEndpoint: stagingEndpoint,
        responseProtection: const ResponseProtection.tlsPinning(
          mode: ResponseProtectionMode.required,
          profile: TlsPinningProfile.datadogStagingV1,
        ),
      ),
      stagingEndpoint,
    ),
  };
  for (final MapEntry(key: target, value: (configuration, endpoint))
      in profiles.entries) {
    test('reports required $target TLS pinning as unsupported on web', () {
      final protection = AssignmentProtection.resolve(
        configuration: configuration,
        endpoint: endpoint,
      )!;

      expect(protection.client, isNull);
      expect(
        protection.error,
        isA<FlagsException>()
            .having(
              (error) => error.type,
              'type',
              FlagsErrorType.invalidConfiguration,
            )
            .having((error) => error.message, 'message', contains('web')),
      );
    });
  }

  test('fails the assignment fetch before sending a request', () async {
    final requests = <http.BaseRequest>[];
    final fetcher = FlagAssignmentsFetcher(
      datadogConfig: datadogConfig,
      configuration: configuration,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 200);
      }),
      protection: AssignmentProtection.resolve(
        configuration: configuration,
        endpoint: DatadogFlagsSite.us1.flagsEndpoint,
      ),
    );

    await expectLater(
      fetcher.fetch(const FlagsEvaluationContext(targetingKey: 'user')),
      throwsA(
        isA<FlagsException>().having(
          (error) => error.type,
          'type',
          FlagsErrorType.invalidConfiguration,
        ),
      ),
    );
    expect(requests, isEmpty);
  });

  test('reports the client as failed after initialization', () async {
    final flags = DatadogFlags();
    addTearDown(flags.disable);
    await flags.enable(configuration: configuration);
    final client = flags.sharedClient();

    await client.initialize(const FlagsEvaluationContext(targetingKey: 'user'));

    expect(
      (client as DatadogFlagsClientLifecycle).status,
      DatadogFlagsClientStatus.error,
    );
  });
}
