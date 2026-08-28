// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/assignment_request_client.dart' as internal;
import 'package:datadog_flags/src/flag_assignments_fetcher.dart';
import 'package:datadog_flags/src/flags_error.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('assignment request reliability', () {
    group('configuration', () {
      test('defaults to no timeout and no retries', () {
        const configuration = DatadogFlagsConfiguration();

        expect(
          configuration.assignmentRequestTimeout,
          Duration.zero,
        );
        expect(configuration.assignmentRequestRetryCount, 0);
      });

      test('default configuration makes exactly one initial request', () async {
        var attempts = 0;
        final fetcher = _fetcher(
          client: MockClient((_) async {
            attempts++;
            return http.Response('retryable', 500);
          }),
        );

        await expectLater(_fetch(fetcher), throwsA(isA<FlagsException>()));

        expect(attempts, 1);
      });

      test('zero-timeout helper is a pass-through', () {
        final client = MockClient((_) async => _successResponse());

        expect(
          withAssignmentRequestTimeout(client, Duration.zero),
          same(client),
        );
      });

      test('zero-retry helper is a pass-through', () {
        final client = MockClient((_) async => _successResponse());

        expect(withAssignmentRequestRetry(client, 0), same(client));
      });

      test('assignment client override bypasses scalar policy', () async {
        var sharedAttempts = 0;
        var assignmentAttempts = 0;
        final assignmentClient = MockClient((_) async {
          assignmentAttempts++;
          return _successResponse();
        });
        final fetcher = _fetcher(
          configuration: DatadogFlagsConfiguration(
            assignmentRequestHttpClient: assignmentClient,
            // Invalid scalar values prove that the fully composed override is
            // used verbatim rather than wrapped in the convenience policy.
            assignmentRequestTimeout: const Duration(milliseconds: -1),
            assignmentRequestRetryCount: 11,
          ),
          client: MockClient((_) async {
            sharedAttempts++;
            return _successResponse();
          }),
        );

        await _fetch(fetcher);

        expect(assignmentAttempts, 1);
        expect(sharedAttempts, 0);
      });

      test('SDK does not close a caller-owned assignment client', () async {
        final assignmentClient = _CloseTrackingClient(
          MockClient((_) async => _successResponse()),
        );
        final sharedClient = MockClient((_) async => _successResponse());
        final flags = DatadogFlags();

        await flags.enable(
          configuration: DatadogFlagsConfiguration(
            datadogConfig: const DatadogFlagsConfig(
              clientToken: 'token',
              env: 'dev',
              site: DatadogFlagsSite.us1,
            ),
            httpClient: sharedClient,
            assignmentRequestHttpClient: assignmentClient,
          ),
        );
        await flags.disable();

        expect(assignmentClient.closed, isFalse);
        assignmentClient.close();
      });

      test('assignment override is isolated from telemetry', () async {
        var assignmentAttempts = 0;
        final telemetryRequests = <http.Request>[];
        final flags = DatadogFlags();
        await flags.enable(
          configuration: DatadogFlagsConfiguration(
            datadogConfig: const DatadogFlagsConfig(
              clientToken: 'token',
              env: 'dev',
              site: DatadogFlagsSite.us1,
            ),
            assignmentRequestHttpClient: MockClient((_) async {
              assignmentAttempts++;
              return _successResponse();
            }),
            httpClient: MockClient((request) async {
              telemetryRequests.add(request);
              return http.Response('', 202);
            }),
          ),
        );

        final client = flags.sharedClient();
        await client.initialize(
          const FlagsEvaluationContext(targetingKey: 'subject'),
        );
        client.getBooleanDetails(key: 'missing', defaultValue: false);
        await flags.disable();

        expect(assignmentAttempts, 1);
        expect(telemetryRequests, isNotEmpty);
        expect(
          telemetryRequests,
          everyElement(
            isA<http.Request>().having(
              (request) => request.url.path,
              'path',
              isNot(contains('precompute-assignments')),
            ),
          ),
        );
      });
    });

    group('retry classification', () {
      test('retries transient client failures', () async {
        for (final error in [
          http.ClientException('offline'),
          TimeoutException('timed out'),
        ]) {
          var attempts = 0;
          final fetcher = _fetcher(
            configuration: const DatadogFlagsConfiguration(
              assignmentRequestRetryCount: 1,
            ),
            client: MockClient((_) async {
              attempts++;
              if (attempts == 1) {
                throw error;
              }
              return _successResponse();
            }),
          );

          await _fetch(fetcher);

          expect(attempts, 2, reason: '$error should be retried');
        }
      });

      test('does not retry non-transport failures', () async {
        var attempts = 0;
        final fetcher = _fetcher(
          configuration: const DatadogFlagsConfiguration(
            assignmentRequestRetryCount: 3,
          ),
          client: MockClient((_) async {
            attempts++;
            throw StateError('invalid client state');
          }),
        );

        await expectLater(
          _fetch(fetcher),
          throwsA(
            isA<FlagsException>().having(
              (error) => error.cause,
              'cause',
              isA<StateError>(),
            ),
          ),
        );

        expect(attempts, 1);
      });

      for (final statusCode in [408, 500, 503, 599]) {
        test('retries HTTP $statusCode', () async {
          var attempts = 0;
          final fetcher = _fetcher(
            configuration: const DatadogFlagsConfiguration(
              assignmentRequestRetryCount: 1,
            ),
            client: MockClient((_) async {
              attempts++;
              return attempts == 1
                  ? http.Response('retry', statusCode)
                  : _successResponse();
            }),
          );

          await _fetch(fetcher);

          expect(attempts, 2);
        });
      }

      for (final statusCode in [400, 429]) {
        test('does not retry HTTP $statusCode', () async {
          var attempts = 0;
          final fetcher = _fetcher(
            configuration: const DatadogFlagsConfiguration(
              assignmentRequestRetryCount: 3,
            ),
            client: MockClient((_) async {
              attempts++;
              return http.Response('do not retry', statusCode);
            }),
          );

          await expectLater(_fetch(fetcher), throwsA(isA<FlagsException>()));

          expect(attempts, 1);
        });
      }

      test('uses the configured retry count after the first attempt', () async {
        var attempts = 0;
        final fetcher = _fetcher(
          configuration: const DatadogFlagsConfiguration(
            assignmentRequestRetryCount: 2,
          ),
          client: MockClient((_) async {
            attempts++;
            return http.Response('retry', 500);
          }),
        );

        await expectLater(_fetch(fetcher), throwsA(isA<FlagsException>()));

        expect(attempts, 3);
      });
    });

    group('timeout and request replay', () {
      test('public helpers compose timeout inside retry', () async {
        final stalledBody = StreamController<List<int>>();
        addTearDown(stalledBody.close);
        final requests = <http.BaseRequest>[];
        final transport = withAssignmentRequestRetry(
          withAssignmentRequestTimeout(
            MockClient.streaming((request, _) async {
              requests.add(request);
              return requests.length == 1
                  ? http.StreamedResponse(stalledBody.stream, 200)
                  : _streamedSuccessResponse();
            }),
            const Duration(milliseconds: 10),
          ),
          1,
        );
        final fetcher = _fetcher(
          configuration: DatadogFlagsConfiguration(
            assignmentRequestHttpClient: transport,
          ),
          client: MockClient((_) async => throw StateError('not used')),
        );

        await _fetch(fetcher);

        expect(requests, hasLength(2));
        expect(requests, everyElement(isA<http.AbortableRequest>()));
      });

      test('caller cancellation interrupts retry backoff', () async {
        final abort = Completer<void>();
        final delayStarted = Completer<void>();
        final blockedDelay = Completer<void>();
        var attempts = 0;
        final transport = internal.buildAssignmentRequestClient(
          MockClient((_) async {
            attempts++;
            return http.Response('retry', 500);
          }),
          timeout: Duration.zero,
          retries: 1,
          delay: (_) {
            delayStarted.complete();
            return blockedDelay.future;
          },
        );
        final request = http.AbortableRequest(
          'POST',
          Uri.parse('https://example.com/assignments'),
          abortTrigger: abort.future,
        )..body = '{}';

        final response = transport.send(request);
        await delayStarted.future;
        abort.complete();

        await expectLater(
            response, throwsA(isA<http.RequestAbortedException>()));
        expect(attempts, 1);
      });

      test('caller cancellation does not depend on inner client support',
          () async {
        final abort = Completer<void>();
        final requestStarted = Completer<void>();
        final pending = Completer<http.StreamedResponse>();
        final transport = withAssignmentRequestTimeout(
          MockClient.streaming((_, __) {
            requestStarted.complete();
            return pending.future;
          }),
          const Duration(seconds: 30),
        );
        final request = http.AbortableRequest(
          'POST',
          Uri.parse('https://example.com/assignments'),
          abortTrigger: abort.future,
        )..body = '{}';

        final response = transport.send(request);
        await requestStarted.future;
        abort.complete();

        await expectLater(
          response,
          throwsA(isA<http.RequestAbortedException>()),
        );
      });

      test('a failing abort trigger is contained as cancellation', () async {
        final abort = Completer<void>();
        final delayStarted = Completer<void>();
        final blockedDelay = Completer<void>();
        var attempts = 0;
        final transport = internal.buildAssignmentRequestClient(
          MockClient((_) async {
            attempts++;
            return http.Response('retry', 500);
          }),
          timeout: Duration.zero,
          retries: 1,
          delay: (_) {
            delayStarted.complete();
            return blockedDelay.future;
          },
        );
        final request = http.AbortableRequest(
          'POST',
          Uri.parse('https://example.com/assignments'),
          abortTrigger: abort.future,
        )..body = '{}';

        final response = transport.send(request);
        await delayStarted.future;
        abort.completeError(StateError('broken abort trigger'));

        await expectLater(
            response, throwsA(isA<http.RequestAbortedException>()));
        expect(attempts, 1);
      });

      test('helpers reject non-assignment request subtypes', () async {
        var attempts = 0;
        final transport = withAssignmentRequestRetry(
          MockClient.streaming((_, __) async {
            attempts++;
            return _streamedSuccessResponse();
          }),
          1,
        );
        final request = http.StreamedRequest(
          'POST',
          Uri.parse('https://example.com/assignments'),
        );
        request.sink.close();

        await expectLater(transport.send(request), throwsArgumentError);
        expect(attempts, 0);
      });

      test('the default disables the per-attempt timeout', () async {
        final requestTypes = <Type>[];
        final fetcher = _fetcher(
          configuration: const DatadogFlagsConfiguration(
            assignmentRequestRetryCount: 0,
          ),
          client: MockClient.streaming((request, _) async {
            requestTypes.add(request.runtimeType);
            return _streamedSuccessResponse();
          }),
        );

        await _fetch(fetcher);

        expect(requestTypes, [http.Request]);
      });

      test('an explicit zero disables the per-attempt timeout', () async {
        final requestTypes = <Type>[];
        final fetcher = _fetcher(
          configuration: const DatadogFlagsConfiguration(
            assignmentRequestTimeout: Duration.zero,
            assignmentRequestRetryCount: 0,
          ),
          client: MockClient.streaming((request, _) async {
            requestTypes.add(request.runtimeType);
            return _streamedSuccessResponse();
          }),
        );

        await _fetch(fetcher);

        expect(requestTypes, [http.Request]);
      });

      test('timeout includes downloading the complete response body', () async {
        final responseBody = StreamController<List<int>>();
        addTearDown(responseBody.close);
        http.BaseRequest? request;
        final fetcher = _fetcher(
          configuration: const DatadogFlagsConfiguration(
            assignmentRequestTimeout: Duration(milliseconds: 10),
            assignmentRequestRetryCount: 0,
          ),
          client: MockClient.streaming((attempt, _) async {
            request = attempt;
            return http.StreamedResponse(responseBody.stream, 200);
          }),
        );

        await expectLater(
          _fetch(fetcher),
          throwsA(
            isA<FlagsException>().having(
              (error) => error.cause,
              'cause',
              isA<TimeoutException>(),
            ),
          ),
        );

        expect(request, isA<http.AbortableRequest>());
        await expectLater(
          (request as http.AbortableRequest).abortTrigger,
          completes,
        );
      });

      test('applies the timeout independently to each attempt', () async {
        final stalledBody = StreamController<List<int>>();
        addTearDown(stalledBody.close);
        final requests = <http.BaseRequest>[];
        final fetcher = _fetcher(
          configuration: const DatadogFlagsConfiguration(
            assignmentRequestTimeout: Duration(milliseconds: 10),
            assignmentRequestRetryCount: 1,
          ),
          client: MockClient.streaming((request, _) async {
            requests.add(request);
            return requests.length == 1
                ? http.StreamedResponse(stalledBody.stream, 200)
                : _streamedSuccessResponse();
          }),
        );

        await _fetch(fetcher);

        expect(requests, hasLength(2));
        expect(identical(requests.first, requests.last), isFalse);
        await expectLater(
          (requests.first as http.AbortableRequest).abortTrigger,
          completes,
        );
      });

      test(
        'creates a fresh request and preserves its body and headers',
        () async {
          final requests = <http.BaseRequest>[];
          final bodies = <String>[];
          final fetcher = _fetcher(
            configuration: const DatadogFlagsConfiguration(
              customFlagsHeaders: {'x-custom': 'value'},
              assignmentRequestRetryCount: 1,
            ),
            client: MockClient.streaming((request, body) async {
              requests.add(request);
              bodies.add(utf8.decode(await body.toBytes()));
              return requests.length == 1
                  ? http.StreamedResponse(const Stream.empty(), 500)
                  : _streamedSuccessResponse();
            }),
          );

          await _fetch(fetcher);

          expect(requests, hasLength(2));
          expect(identical(requests.first, requests.last), isFalse);
          expect(bodies.first, bodies.last);
          for (final request in requests) {
            expect(request.headers['dd-client-token'], 'token');
            expect(request.headers['x-custom'], 'value');
            expect(request.headers['content-type'], 'application/vnd.api+json');
          }
        },
      );
    });

    group('retry delay', () {
      test('uses bounded exponential full-jitter backoff', () async {
        final delays = <Duration>[];
        var attempts = 0;
        final fetcher = _fetcher(
          configuration: const DatadogFlagsConfiguration(
            assignmentRequestRetryCount: 10,
          ),
          client: MockClient((_) async {
            attempts++;
            return attempts == 11
                ? _successResponse()
                : http.Response('retry', 500);
          }),
          delays: delays,
          randomDouble: () => 0.5,
        );

        await _fetch(fetcher);

        expect(delays, [
          const Duration(milliseconds: 50),
          const Duration(milliseconds: 100),
          const Duration(milliseconds: 200),
          const Duration(milliseconds: 400),
          const Duration(milliseconds: 800),
          const Duration(milliseconds: 1600),
          const Duration(milliseconds: 3200),
          const Duration(milliseconds: 6400),
          const Duration(milliseconds: 12800),
          const Duration(milliseconds: 15000),
        ]);
      });

      test('uses Retry-After seconds as a floor before jitter', () async {
        final delays = <Duration>[];
        var attempts = 0;
        final fetcher = _fetcher(
          configuration: const DatadogFlagsConfiguration(
            assignmentRequestRetryCount: 1,
          ),
          client: MockClient((_) async {
            attempts++;
            return attempts == 1
                ? http.Response('retry', 503, headers: {'retry-after': '1'})
                : _successResponse();
          }),
          delays: delays,
          randomDouble: () => 0.5,
        );

        await _fetch(fetcher);

        expect(delays, [const Duration(milliseconds: 1050)]);
      });

      test('uses Retry-After HTTP dates as a floor before jitter', () async {
        final delays = <Duration>[];
        var attempts = 0;
        final fetcher = _fetcher(
          configuration: DatadogFlagsConfiguration(
            assignmentRequestRetryCount: 1,
            dateProvider: () => DateTime.utc(2026, 8, 28, 16),
          ),
          client: MockClient((_) async {
            attempts++;
            return attempts == 1
                ? http.Response(
                    'retry',
                    503,
                    headers: {'retry-after': 'Fri, 28 Aug 2026 16:00:01 GMT'},
                  )
                : _successResponse();
          }),
          delays: delays,
          randomDouble: () => 0.5,
        );

        await _fetch(fetcher);

        expect(delays, [const Duration(milliseconds: 1050)]);
      });

      for (final retryAfter in [
        '0',
        'Wed, 21 Oct 2015 07:28:00 GMT',
      ]) {
        test('uses jitter when Retry-After is immediate or past', () async {
          final delays = <Duration>[];
          var attempts = 0;
          final fetcher = _fetcher(
            configuration: DatadogFlagsConfiguration(
              assignmentRequestRetryCount: 1,
              dateProvider: () => DateTime.utc(2026, 8, 28, 16),
            ),
            client: MockClient((_) async {
              attempts++;
              return attempts == 1
                  ? http.Response(
                      'retry',
                      503,
                      headers: {'retry-after': retryAfter},
                    )
                  : _successResponse();
            }),
            delays: delays,
            randomDouble: () => 0.5,
          );

          await _fetch(fetcher);

          expect(delays, [const Duration(milliseconds: 50)]);
        });
      }

      for (final retryAfter in ['31', 'Fri, 28 Aug 2026 16:00:31 GMT']) {
        test('does not retry when Retry-After exceeds 30 seconds', () async {
          var attempts = 0;
          final fetcher = _fetcher(
            configuration: DatadogFlagsConfiguration(
              assignmentRequestRetryCount: 1,
              dateProvider: () => DateTime.utc(2026, 8, 28, 16),
            ),
            client: MockClient((_) async {
              attempts++;
              return http.Response(
                'maintenance',
                503,
                headers: {'retry-after': retryAfter},
              );
            }),
          );

          await expectLater(_fetch(fetcher), throwsA(isA<FlagsException>()));

          expect(attempts, 1);
        });
      }

      test('does not retry an out-of-range Retry-After integer', () async {
        var attempts = 0;
        final fetcher = _fetcher(
          configuration: const DatadogFlagsConfiguration(
            assignmentRequestRetryCount: 1,
          ),
          client: MockClient((_) async {
            attempts++;
            return http.Response(
              'maintenance',
              503,
              headers: {
                'retry-after': '999999999999999999999999999999999999999999',
              },
            );
          }),
        );

        await expectLater(_fetch(fetcher), throwsA(isA<FlagsException>()));

        expect(attempts, 1);
      });

      test('falls back to jitter for malformed Retry-After', () async {
        final delays = <Duration>[];
        var attempts = 0;
        final fetcher = _fetcher(
          configuration: const DatadogFlagsConfiguration(
            assignmentRequestRetryCount: 1,
          ),
          client: MockClient((_) async {
            attempts++;
            return attempts == 1
                ? http.Response('retry', 503, headers: {'retry-after': '1.5'})
                : _successResponse();
          }),
          delays: delays,
          randomDouble: () => 0.5,
        );

        await _fetch(fetcher);

        expect(delays, [const Duration(milliseconds: 50)]);
      });

      test('ignores Retry-After on statuses other than 503', () async {
        final delays = <Duration>[];
        var attempts = 0;
        final fetcher = _fetcher(
          configuration: const DatadogFlagsConfiguration(
            assignmentRequestRetryCount: 1,
          ),
          client: MockClient((_) async {
            attempts++;
            return attempts == 1
                ? http.Response('retry', 500, headers: {'retry-after': '10'})
                : _successResponse();
          }),
          delays: delays,
          randomDouble: () => 0.5,
        );

        await _fetch(fetcher);

        expect(delays, [const Duration(milliseconds: 50)]);
      });
    });

    group('input validation', () {
      test('rejects a negative timeout before sending a request', () async {
        var attempts = 0;
        final fetcher = _fetcher(
          configuration: const DatadogFlagsConfiguration(
            assignmentRequestTimeout: Duration(milliseconds: -1),
          ),
          client: MockClient((_) async {
            attempts++;
            return _successResponse();
          }),
        );

        await expectLater(_fetch(fetcher), throwsArgumentError);

        expect(attempts, 0);
      });

      for (final retryCount in [-1, 11]) {
        test(
          'rejects retry count $retryCount before sending a request',
          () async {
            var attempts = 0;
            final fetcher = _fetcher(
              configuration: DatadogFlagsConfiguration(
                assignmentRequestRetryCount: retryCount,
              ),
              client: MockClient((_) async {
                attempts++;
                return _successResponse();
              }),
            );

            await expectLater(_fetch(fetcher), throwsRangeError);

            expect(attempts, 0);
          },
        );
      }
    });
  });
}

FlagAssignmentsFetcher _fetcher({
  required http.Client client,
  DatadogFlagsConfiguration configuration = const DatadogFlagsConfiguration(),
  List<Duration>? delays,
  double Function()? randomDouble,
}) {
  return FlagAssignmentsFetcher(
    datadogConfig: const DatadogFlagsConfig(
      clientToken: 'token',
      env: 'dev',
      site: DatadogFlagsSite.us1,
    ),
    configuration: configuration,
    httpClient: client,
    delay: delays == null
        ? (_) async {}
        : (duration) async {
            delays.add(duration);
          },
    randomDouble: randomDouble ?? () => 0,
  );
}

Future<void> _fetch(FlagAssignmentsFetcher fetcher) async {
  await fetcher.fetch(const FlagsEvaluationContext(targetingKey: 'subject'));
}

http.Response _successResponse() {
  return http.Response(jsonEncode({'data': _emptyAssignments()}), 200);
}

http.StreamedResponse _streamedSuccessResponse() {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode({'data': _emptyAssignments()}))),
    200,
  );
}

Map<String, Object?> _emptyAssignments() {
  return {
    'attributes': {'flags': <String, Object?>{}},
  };
}

final class _CloseTrackingClient extends http.BaseClient {
  final http.Client _inner;
  bool closed = false;

  _CloseTrackingClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request);
  }

  @override
  void close() {
    closed = true;
    _inner.close();
  }
}
