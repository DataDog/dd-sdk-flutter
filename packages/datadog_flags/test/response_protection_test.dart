// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// Legacy API coverage until the next major release.
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:convert';
import 'dart:typed_data';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/assignment.dart';
import 'package:datadog_flags/src/flag_assignments_fetcher.dart';
import 'package:datadog_flags/src/flags_error.dart';
import 'package:datadog_flags/src/flags_store.dart';
import 'package:datadog_flags/src/response_protection.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'tls_test_certificates.dart';

void main() {
  String certificatePin(String pem) =>
      spkiPin(subjectPublicKeyInfoFromCertificate(derFromPem(pem)));

  group('subjectPublicKeyInfoFromCertificate', () {
    final vectors = {
      'EC P-256 leaf': (leafAEcCertificatePem, leafAEcSpkiPin),
      'RSA 2048 leaf': (leafBRsaCertificatePem, leafBRsaSpkiPin),
      'EC P-256 self-signed CA': (caCertificatePem, caSpkiPin),
    };
    for (final MapEntry(key: name, value: (pem, pin)) in vectors.entries) {
      test('matches the OpenSSL SPKI digest for the $name', () {
        expect(certificatePin(pem), pin);
      });
    }

    final certificate = derFromPem(leafAEcCertificatePem);
    final malformed = {
      'empty input': Uint8List(0),
      'truncated certificate': Uint8List.sublistView(
        certificate,
        0,
        certificate.length - 1,
      ),
      'trailing data': Uint8List.fromList([...certificate, 0]),
      'indefinite length': Uint8List.fromList([0x30, 0x80, 0x00, 0x00]),
      'non-minimal length': Uint8List.fromList([0x30, 0x81, 0x01, 0x00]),
      'wrong outer tag': Uint8List.fromList([0x31, ...certificate.skip(1)]),
    };
    for (final MapEntry(key: name, value: bytes) in malformed.entries) {
      test('rejects $name', () {
        expect(
          () => subjectPublicKeyInfoFromCertificate(bytes),
          throwsFormatException,
        );
      });
    }
  });

  group('TlsPinningPolicy', () {
    final endpoint = Uri.parse('https://flags.example.com/precompute');
    TlsPinningProfile profile({
      Set<String> hosts = const {'flags.example.com'},
      Set<String> pins = const {leafAEcSpkiPin, leafBRsaSpkiPin},
    }) => TlsPinningProfile(name: 'test', hosts: hosts, spkiSha256Pins: pins);

    final invalid = <String, (TlsPinningProfile, Uri)>{
      'one pin': (profile(pins: {leafAEcSpkiPin}), endpoint),
      'no pins': (profile(pins: {}), endpoint),
      'pins equal after decoding': (
        profile(
          pins: {
            leafAEcSpkiPin,
            // The same digest in the URL-safe base64 alphabet.
            leafAEcSpkiPin.replaceAll('/', '_').replaceAll('+', '-'),
          },
        ),
        endpoint,
      ),
      'a pin that is not base64': (
        profile(pins: {leafAEcSpkiPin, 'not base64!'}),
        endpoint,
      ),
      'a pin that is not 32 bytes': (
        profile(pins: {leafAEcSpkiPin, base64.encode(List.filled(20, 1))}),
        endpoint,
      ),
      'no hosts': (profile(hosts: {}), endpoint),
      'a wildcard host': (profile(hosts: {'*.example.com'}), endpoint),
      'a host with a port': (
        profile(hosts: {'flags.example.com:443'}),
        endpoint,
      ),
      'a host with a scheme': (
        profile(hosts: {'https://flags.example.com'}),
        endpoint,
      ),
      'an HTTP endpoint': (
        profile(),
        Uri.parse('http://flags.example.com/precompute'),
      ),
      'an endpoint host outside the profile': (
        profile(),
        Uri.parse('https://other.example.com/precompute'),
      ),
      'an endpoint on a subdomain of a profile host': (
        profile(hosts: {'example.com'}),
        endpoint,
      ),
    };
    for (final MapEntry(key: name, value: (profile, endpoint))
        in invalid.entries) {
      test('rejects a profile with $name', () {
        expect(
          () => TlsPinningPolicy.forEndpoint(profile, endpoint),
          throwsA(
            isA<FlagsException>().having(
              (error) => error.type,
              'type',
              FlagsErrorType.invalidConfiguration,
            ),
          ),
        );
      });
    }

    test('matches hosts without case sensitivity', () {
      final policy = TlsPinningPolicy.forEndpoint(
        profile(hosts: {'FLAGS.Example.com'}),
        endpoint,
      );
      expect(policy.hosts, {'flags.example.com'});
    });

    test('accepts a certificate that matches any pin', () {
      final policy = TlsPinningPolicy.forEndpoint(profile(), endpoint);
      expect(
        policy.matchesCertificate(derFromPem(leafAEcCertificatePem)),
        isTrue,
      );
      expect(
        policy.matchesCertificate(derFromPem(leafBRsaCertificatePem)),
        isTrue,
      );
    });

    test('compares pins with the leaf certificate, not its issuer', () {
      final policy = TlsPinningPolicy.forEndpoint(
        profile(pins: {caSpkiPin, leafAEcSpkiPin}),
        endpoint,
      );
      expect(
        policy.matchesCertificate(derFromPem(leafBRsaCertificatePem)),
        isFalse,
      );
    });

    test('rejects a certificate that cannot be parsed', () {
      final policy = TlsPinningPolicy.forEndpoint(profile(), endpoint);
      expect(policy.matchesCertificate(Uint8List(8)), isFalse);
    });

    final issuerProfiles = <String, (List<String>, Set<String>)>{
      'a certificate that is not pinned': (
        [issuerRootAPem, issuerIntermediateByRootAPem],
        {issuerRootASpkiPin, leafAEcSpkiPin},
      ),
      'a pin without a certificate': (
        [issuerRootAPem, issuerIntermediateByRootAPem],
        {issuerRootASpkiPin, issuerIntermediateSpkiPin, leafAEcSpkiPin},
      ),
      'no certificates': ([], {issuerRootASpkiPin, issuerIntermediateSpkiPin}),
      'a malformed certificate': (
        [issuerRootAPem, 'not a certificate'],
        {issuerRootASpkiPin, issuerIntermediateSpkiPin},
      ),
      'two certificates in one entry': (
        [issuerRootAPem + issuerIntermediateByRootAPem],
        {issuerRootASpkiPin, issuerIntermediateSpkiPin},
      ),
    };
    for (final MapEntry(key: name, value: (certificates, pins))
        in issuerProfiles.entries) {
      test('rejects an issuer profile with $name', () {
        expect(
          () => TlsPinningPolicy.forEndpoint(
            TlsPinningProfile.issuer(
              name: 'test',
              hosts: const {'flags.example.com'},
              spkiSha256Pins: pins,
              issuerCertificates: certificates,
            ),
            endpoint,
          ),
          throwsA(
            isA<FlagsException>().having(
              (error) => error.type,
              'type',
              FlagsErrorType.invalidConfiguration,
            ),
          ),
        );
      });
    }

    test('accepts an issuer profile whose certificates match its pins', () {
      final policy = TlsPinningPolicy.forEndpoint(
        const TlsPinningProfile.issuer(
          name: 'test',
          hosts: {'flags.example.com'},
          spkiSha256Pins: {issuerRootASpkiPin, issuerIntermediateSpkiPin},
          issuerCertificates: [issuerRootAPem, issuerIntermediateByRootAPem],
        ),
        endpoint,
      );
      expect(policy.target, TlsPinTarget.issuer);
      expect(policy.issuerCertificates, hasLength(2));
    });

    test('custom profiles pin the leaf certificate', () {
      expect(profile().target, TlsPinTarget.leaf);
      expect(profile().issuerCertificates, isEmpty);
    });

    group('datadogStagingV1', () {
      const staging = TlsPinningProfile.datadogStagingV1;
      final stagingEndpoint = Uri.parse(
        'https://protected.ff-cdn.datad0g.com/precompute-assignments',
      );

      test('pins the Certainly issuers of the protected staging host', () {
        final policy = TlsPinningPolicy.forEndpoint(staging, stagingEndpoint);
        expect(policy.target, TlsPinTarget.issuer);
        expect(policy.hosts, {'protected.ff-cdn.datad0g.com'});
        expect(
          policy.pins,
          containsAll(const {
            // Certainly Intermediate R1.
            'oW7smChMJRcnzTObF7K+HzInReAPTxB/L1h6eZTmw9Q=',
            // Certainly Root R1.
            'P5Pz/PedIl0hPu9qSj9Yhc+E/j16ejwRVTUXaIwOIQA=',
            // Certainly Root E1.
            'HvZGJdqi5dQz10Sa4xogDRAl4AEqj+z6cJMvi1mbdd0=',
          }),
        );
      });

      test('bundles one certificate for each pin', () {
        expect({
          for (final pem in staging.issuerCertificates) certificatePin(pem),
        }, staging.spkiSha256Pins);
      });

      test('does not cover the preview staging host', () {
        expect(
          () => TlsPinningPolicy.forEndpoint(
            staging,
            DatadogFlagsSite.us1Staging.flagsEndpoint,
          ),
          throwsA(isA<FlagsException>()),
        );
      });
    });
  });

  group('assignment endpoint under TLS pinning', () {
    const stagingConfig = DatadogFlagsConfig(
      clientToken: 'client-token',
      env: 'staging',
      site: DatadogFlagsSite.us1Staging,
    );
    const staging = ResponseProtection.tlsPinning(
      mode: ResponseProtectionMode.required,
      profile: TlsPinningProfile.datadogStagingV1,
    );
    final protectedEndpoint = Uri.parse(
      'https://protected.ff-cdn.datad0g.com/precompute-assignments',
    );

    test('uses the profile host instead of the site host', () {
      expect(
        flagAssignmentsEndpoint(
          datadogConfig: stagingConfig,
          configuration: const DatadogFlagsConfiguration(
            responseProtection: staging,
          ),
        ),
        protectedEndpoint,
      );
    });

    test('posts to the profile host with the capabilities header', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'data': {
              'attributes': {'flags': <String, Object?>{}},
            },
          }),
          200,
        );
      });
      const configuration = DatadogFlagsConfiguration(
        datadogConfig: stagingConfig,
        responseProtection: staging,
      );

      await FlagAssignmentsFetcher(
        datadogConfig: stagingConfig,
        configuration: configuration,
        httpClient: MockClient((_) async => http.Response('', 500)),
        protection: AssignmentProtection(policyId: 'test', client: client),
      ).fetch(const FlagsEvaluationContext(targetingKey: 'user'));

      expect(requests.single.url, protectedEndpoint);
      expect(
        requests.single.headers['X-DD-FEATURE-FLAGS-CAPABILITIES'],
        isNotEmpty,
      );
    });

    test('rejects a custom endpoint on another host', () {
      final protection = AssignmentProtection.resolve(
        configuration: DatadogFlagsConfiguration(
          datadogConfig: stagingConfig,
          customFlagsEndpoint: DatadogFlagsSite.us1Staging.flagsEndpoint,
          responseProtection: staging,
        ),
        endpoint: DatadogFlagsSite.us1Staging.flagsEndpoint,
      )!;

      expect(
        protection.error,
        isA<FlagsException>().having(
          (error) => error.message,
          'message',
          contains('is not in the profile'),
        ),
      );
    });

    final multiHost = ResponseProtection.tlsPinning(
      mode: ResponseProtectionMode.required,
      profile: TlsPinningProfile(
        name: 'test',
        hosts: const {'a.example.com', 'b.example.com'},
        spkiSha256Pins: const {leafAEcSpkiPin, leafBRsaSpkiPin},
      ),
    );
    final multiHostCases = {
      'requires a custom endpoint for a profile with several hosts': (
        null,
        isA<FlagsException>().having(
          (error) => error.message,
          'message',
          contains('more than one host'),
        ),
      ),
      'accepts a custom endpoint on one of several profile hosts': (
        Uri.parse('https://b.example.com/precompute-assignments'),
        // Web reports TLS pinning as unsupported instead.
        anyOf(
          isNull,
          isA<FlagsException>().having(
            (error) => error.message,
            'message',
            contains('web'),
          ),
        ),
      ),
    };
    for (final MapEntry(key: name, value: (customEndpoint, matcher))
        in multiHostCases.entries) {
      test(name, () {
        final configuration = DatadogFlagsConfiguration(
          datadogConfig: stagingConfig,
          customFlagsEndpoint: customEndpoint,
          responseProtection: multiHost,
        );
        final protection = AssignmentProtection.resolve(
          configuration: configuration,
          endpoint: flagAssignmentsEndpoint(
            datadogConfig: stagingConfig,
            configuration: configuration,
          ),
        )!;
        addTearDown(protection.close);

        expect(protection.error, matcher);
      });
    }
  });

  group('DatadogFlags with required TLS pinning', () {
    const datadogConfig = DatadogFlagsConfig(
      clientToken: 'client-token',
      env: 'test',
      site: DatadogFlagsSite.us1,
    );
    const context = FlagsEvaluationContext(targetingKey: 'user');
    final protection = ResponseProtection.tlsPinning(
      mode: ResponseProtectionMode.required,
      profile: TlsPinningProfile(
        name: 'test',
        hosts: {DatadogFlagsSite.us1.flagsEndpoint.host},
        spkiSha256Pins: {leafAEcSpkiPin, leafBRsaSpkiPin},
      ),
    );

    FlagsData storedData({String? responseProtectionPolicy}) => FlagsData(
      flags: {
        'flag': FlagAssignment.fromJson({
          'variationType': 'boolean',
          'variationValue': true,
          'variationKey': 'on',
          'allocationKey': 'allocation',
          'reason': 'TARGETING_MATCH',
          'doLog': false,
        }),
      },
      context: context,
      date: DateTime.utc(2026),
      responseProtectionPolicy: responseProtectionPolicy,
    );

    test(
      'rejects a custom httpClient without sending an assignment request',
      () async {
        final requests = <http.Request>[];
        final flags = DatadogFlags();
        addTearDown(flags.disable);
        await flags.enable(
          configuration: DatadogFlagsConfiguration(
            datadogConfig: datadogConfig,
            httpClient: MockClient((request) async {
              requests.add(request);
              return http.Response('{}', 200);
            }),
            responseProtection: protection,
            trackExposures: false,
            trackEvaluations: false,
          ),
        );
        final client = flags.sharedClient();

        await client.initialize(context);

        expect(
          (client as DatadogFlagsClientLifecycle).status,
          DatadogFlagsClientStatus.error,
        );
        expect(requests, isEmpty);
      },
    );

    final cacheCases = {
      'assignments fetched without protection': (
        null,
        DatadogFlagsClientStatus.error,
        false,
      ),
      'assignments fetched under another policy': (
        'tlsPinning:other',
        DatadogFlagsClientStatus.error,
        false,
      ),
      'assignments fetched under the same policy': (
        AssignmentProtection.resolve(
          configuration: DatadogFlagsConfiguration(
            datadogConfig: datadogConfig,
            httpClient: MockClient((_) async => http.Response('{}', 200)),
            responseProtection: protection,
          ),
          endpoint: DatadogFlagsSite.us1.flagsEndpoint.replace(
            path: '/precompute-assignments',
          ),
        )!.policyId,
        DatadogFlagsClientStatus.stale,
        true,
      ),
    };
    for (final MapEntry(key: name, value: (policy, status, restored))
        in cacheCases.entries) {
      test('${restored ? 'restores' : 'ignores'} stored $name', () async {
        final store = InMemoryDatadogFlagsStore();
        await store.write(
          DatadogFlags.defaultClientName,
          storedData(responseProtectionPolicy: policy),
        );
        final flags = DatadogFlags();
        addTearDown(flags.disable);
        await flags.enable(
          configuration: DatadogFlagsConfiguration(
            datadogConfig: datadogConfig,
            // A custom client makes every protected fetch fail locally.
            httpClient: MockClient((_) async => http.Response('{}', 200)),
            responseProtection: protection,
            store: store,
            trackExposures: false,
            trackEvaluations: false,
          ),
        );
        final client = flags.sharedClient();

        await client.initialize(context);

        expect((client as DatadogFlagsClientLifecycle).status, status);
        expect(
          client.getBooleanDetails(key: 'flag', defaultValue: false).value,
          restored,
        );
      });
    }

    test('stores the policy identifier with stored assignments', () {
      final data = storedData(responseProtectionPolicy: 'tlsPinning:abc');
      expect(
        FlagsData.fromJson(data.toJson()).responseProtectionPolicy,
        'tlsPinning:abc',
      );
      expect(
        storedData().toJson(),
        isNot(contains('responseProtectionPolicy')),
      );
    });
  });
}
