// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

// ignore_for_file: invalid_use_of_internal_member

import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_platform_interface.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDatadogSessionReplayPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DatadogSessionReplayPlatform {}

class MockInternalLogger extends Mock implements InternalLogger {}

/// Fixed RUM session IDs, one per session, spread over the 48-bit seed space
/// the sampler reads from the end of the UUID.
final sessionIds = List.generate(1000, (i) {
  final seed = ((i + 1) * 0x9E3779B97F4A).toUnsigned(48);
  return '00000000-0000-4000-8000-${seed.toRadixString(16).padLeft(12, '0')}';
});

/// The sessions [DeterministicSampler] selects at [rumSampleRate], combined
/// with [childSampleRate] when given. This is the decision the native SDKs
/// make for the same session ID, so Session Replay must match it exactly.
Set<String> sampledSessions(double rumSampleRate, [double? childSampleRate]) {
  return sessionIds.where((id) {
    final rumSampler = DeterministicSampler(rumSampleRate);
    final sampler = childSampleRate == null
        ? rumSampler
        : rumSampler.combined(childSampleRate);
    return sampler.sampleUuid(id);
  }).toSet();
}

/// The context native sends for a session; the session ID doubles as the view
/// ID so `has_replay` can be mapped back to its session.
RUMContext sessionContext(String sessionId) =>
    RUMContext(applicationId: 'app', sessionId: sessionId, viewId: sessionId);

/// What native sends when there is no sampled RUM session (iOS sends nil,
/// which the iOS platform forwards as this; Android sends empty IDs).
const noSessionContext = RUMContext(applicationId: '', sessionId: '');

/// What Android sends when there is no active RUM session: its `NULL_UUID`
/// (`RumSessionConstants.EMPTY_RUM_SESSION_ID`) for both IDs.
const androidNoSessionContext = RUMContext(
  applicationId: '00000000-0000-0000-0000-000000000000',
  sessionId: '00000000-0000-0000-0000-000000000000',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockPlatform = MockDatadogSessionReplayPlatform();
  void Function(RUMContext)? deliverRumContext;
  final viewsWithReplay = <String>{};

  setUpAll(() {
    registerFallbackValue(
      DatadogSessionReplayConfiguration(replaySampleRate: 100),
    );
  });

  setUp(() {
    deliverRumContext = null;
    viewsWithReplay.clear();
    DatadogSessionReplayPlatform.instance = mockPlatform;
    when(() => mockPlatform.enable(any(), any())).thenAnswer((invocation) {
      deliverRumContext =
          invocation.positionalArguments[1] as void Function(RUMContext);
      // Returning false avoids spawning the processor isolate in tests
      return Future.value(false);
    });
    when(() => mockPlatform.setHasReplay(any(), any()))
        .thenAnswer((invocation) {
      if (invocation.positionalArguments[1] == true) {
        viewsWithReplay.add(invocation.positionalArguments[0] as String);
      }
    });
  });

  tearDown(() {
    DatadogSessionReplay.resetInstance();
  });

  /// One Session Replay instance with recording requested, as an app calling
  /// startRecording() would have.
  Future<DatadogSessionReplay> startSessionReplay({
    required double rumSampleRate,
    required double replaySampleRate,
    bool isEmbedded = false,
  }) async {
    final sessionReplay = await DatadogSessionReplay.init(
      DatadogSessionReplayConfiguration(
        replaySampleRate: replaySampleRate,
        isEmbedded: isEmbedded,
        startRecordingImmediately: false,
      ),
      MockInternalLogger(),
      rumSampleRate: rumSampleRate,
    );
    sessionReplay.startRecording();
    return sessionReplay;
  }

  /// Runs every session in [sessionIds] through one Session Replay instance,
  /// as a long-lived app whose RUM session renews, and returns the sessions
  /// during which it captured.
  ///
  /// Like native, only sessions RUM samples get their context delivered; the
  /// others get [noSessionContext].
  Future<Set<String>> recordedSessions({
    required double rumSampleRate,
    required double replaySampleRate,
    bool isEmbedded = false,
  }) async {
    final sessionReplay = await startSessionReplay(
      rumSampleRate: rumSampleRate,
      replaySampleRate: replaySampleRate,
      isEmbedded: isEmbedded,
    );

    final rumSampled = sampledSessions(rumSampleRate);
    final recorded = <String>{};
    for (final sessionId in sessionIds) {
      deliverRumContext!(
        rumSampled.contains(sessionId)
            ? sessionContext(sessionId)
            : noSessionContext,
      );
      if (sessionReplay.isCapturing) recorded.add(sessionId);
    }
    return recorded;
  }

  group('replaySampleRate', () {
    for (final rate in [0.0, 10.0, 20.0, 50.0, 100.0]) {
      test('$rate records exactly the sessions sampled at $rate%', () async {
        final recorded = await recordedSessions(
          rumSampleRate: 100,
          replaySampleRate: rate,
        );

        expect(recorded, sampledSessions(100, rate));
        expect(viewsWithReplay, recorded);
        if (rate == 0) expect(recorded, isEmpty);
        if (rate == 100) expect(recorded, sessionIds.toSet());
      });
    }

    test('the same sessions always get the same decision', () async {
      final first =
          await recordedSessions(rumSampleRate: 100, replaySampleRate: 50);
      DatadogSessionReplay.resetInstance();
      final second =
          await recordedSessions(rumSampleRate: 100, replaySampleRate: 50);

      expect(second, first);
    });
  });

  group('replaySampleRate with RUM sessionSampleRate below 100', () {
    for (final rumRate in [0.0, 10.0, 50.0]) {
      for (final replayRate in [0.0, 10.0, 20.0, 50.0, 100.0]) {
        test(
            'RUM $rumRate% x replay $replayRate% records exactly the sessions '
            'sampled at the combined rate', () async {
          final recorded = await recordedSessions(
            rumSampleRate: rumRate,
            replaySampleRate: replayRate,
          );

          expect(recorded, sampledSessions(rumRate, replayRate));
          expect(viewsWithReplay, recorded);
          // Every session with a replay is also a RUM session.
          expect(recorded.difference(sampledSessions(rumRate)), isEmpty);
        });
      }
    }
  });

  group('session changes during a launch', () {
    // Sessions picked by the same sampler: one sampled at RUM 50% x replay
    // 50%, one that RUM samples but replay doesn't.
    late String sampled;
    late String notSampled;

    setUp(() {
      final replaySampled = sampledSessions(50, 50);
      sampled = replaySampled.first;
      notSampled = sampledSessions(50).difference(replaySampled).first;
    });

    test('recording follows the decision of each new session', () async {
      final sessionReplay =
          await startSessionReplay(rumSampleRate: 50, replaySampleRate: 50);

      deliverRumContext!(sessionContext(sampled));
      expect(sessionReplay.isCapturing, isTrue);

      deliverRumContext!(sessionContext(notSampled));
      expect(sessionReplay.isCapturing, isFalse);

      deliverRumContext!(sessionContext(sampled));
      expect(sessionReplay.isCapturing, isTrue);
    });

    test('a session that is not sampled never reports has_replay', () async {
      await startSessionReplay(rumSampleRate: 50, replaySampleRate: 50);

      deliverRumContext!(sessionContext(notSampled));

      expect(viewsWithReplay, isEmpty);
    });

    test('startRecording() before any session waits for a sampled one',
        () async {
      final sessionReplay =
          await startSessionReplay(rumSampleRate: 50, replaySampleRate: 50);
      expect(sessionReplay.isCapturing, isFalse);

      deliverRumContext!(sessionContext(sampled));

      expect(sessionReplay.isCapturing, isTrue);
    });

    test('stopRecording() is kept across session changes', () async {
      final sessionReplay =
          await startSessionReplay(rumSampleRate: 50, replaySampleRate: 50);
      deliverRumContext!(sessionContext(sampled));

      sessionReplay.stopRecording();
      deliverRumContext!(sessionContext(notSampled));
      deliverRumContext!(sessionContext(sampled));

      expect(sessionReplay.isCapturing, isFalse);
    });

    test('losing the RUM session stops recording', () async {
      final sessionReplay =
          await startSessionReplay(rumSampleRate: 50, replaySampleRate: 50);
      deliverRumContext!(sessionContext(sampled));

      deliverRumContext!(noSessionContext);

      expect(sessionReplay.isCapturing, isFalse);
    });

    test("Android's all-zero session ID is treated as no session", () async {
      // At 100% every real session records, and the all-zero ID hashes to 0,
      // which the sampler accepts at any rate. Only the no-session check keeps
      // it from recording.
      final sessionReplay =
          await startSessionReplay(rumSampleRate: 100, replaySampleRate: 100);

      deliverRumContext!(androidNoSessionContext);

      expect(sessionReplay.isCapturing, isFalse);
      expect(viewsWithReplay, isEmpty);
    });

    test('losing the RUM session on Android (all-zero ID) stops recording',
        () async {
      final sessionReplay =
          await startSessionReplay(rumSampleRate: 50, replaySampleRate: 50);
      deliverRumContext!(sessionContext(sampled));
      expect(sessionReplay.isCapturing, isTrue);

      deliverRumContext!(androidNoSessionContext);

      expect(sessionReplay.isCapturing, isFalse);
    });
  });

  // Native RUM ends a session after 15 minutes without interaction, or once
  // it is 4 hours old. Flutter Session Replay has no timers of its own: it
  // only sees the RUM contexts native sends. On renewal native moves the
  // active view into the new session, so the next context has a new session
  // ID and a new view ID. Each scenario below replays that context stream.
  group('session renewal during a launch', () {
    // Sessions picked by the same sampler at RUM 50% x replay 50%.
    late String sampled;
    late String otherSampled;
    late String replayNotSampled;

    setUp(() {
      final rumSampled = sampledSessions(50);
      final replaySampled = sampledSessions(50, 50).toList();
      sampled = replaySampled[0];
      otherSampled = replaySampled[1];
      replayNotSampled = rumSampled.difference(replaySampled.toSet()).first;
    });

    RUMContext viewContext(String sessionId, int view) => RUMContext(
          applicationId: 'app',
          sessionId: sessionId,
          viewId: '$sessionId/view-$view',
        );

    /// Contexts native sends during [sessionId] for each renewal reason:
    ///
    /// * inactivity: the user opens a couple of screens, then leaves the app
    ///   idle for 15 minutes, so no further context arrives.
    /// * max duration: the user keeps navigating for 4 hours, one screen every
    ///   5 minutes, all within the same session.
    ///
    /// Returns the view IDs that were delivered.
    final renewals = <String, List<String> Function(String sessionId)>{
      'after 15 minutes of inactivity': (sessionId) {
        final views = <String>[];
        for (var view = 0; view < 2; view++) {
          deliverRumContext!(viewContext(sessionId, view));
          views.add('$sessionId/view-$view');
        }
        return views;
      },
      'after the session reaches 4 hours': (sessionId) {
        final views = <String>[];
        for (var view = 0; view < 4 * 60 ~/ 5; view++) {
          deliverRumContext!(viewContext(sessionId, view));
          views.add('$sessionId/view-$view');
        }
        return views;
      },
    };

    /// The first context native sends for a renewed session: the active view
    /// transferred into it, or no session if RUM does not sample it.
    void renewInto(String? sessionId) {
      deliverRumContext!(
        sessionId == null ? noSessionContext : viewContext(sessionId, 0),
      );
    }

    for (final MapEntry(key: reason, value: playSession) in renewals.entries) {
      group(reason, () {
        test('a sampled session renewed into a sampled one keeps recording',
            () async {
          final sessionReplay =
              await startSessionReplay(rumSampleRate: 50, replaySampleRate: 50);

          final firstViews = playSession(sampled);
          expect(sessionReplay.isCapturing, isTrue);

          renewInto(otherSampled);

          expect(sessionReplay.isCapturing, isTrue);
          expect(
            viewsWithReplay,
            {...firstViews, '$otherSampled/view-0'},
          );
        });

        test('renewal into a session replay does not sample stops recording',
            () async {
          final sessionReplay =
              await startSessionReplay(rumSampleRate: 50, replaySampleRate: 50);
          final firstViews = playSession(sampled);

          renewInto(replayNotSampled);
          playSession(replayNotSampled);

          expect(sessionReplay.isCapturing, isFalse);
          // Only the first session's views report has_replay.
          expect(viewsWithReplay, firstViews.toSet());
        });

        test('renewal into a session RUM does not sample stops recording',
            () async {
          final sessionReplay =
              await startSessionReplay(rumSampleRate: 50, replaySampleRate: 50);
          final firstViews = playSession(sampled);

          renewInto(null);

          expect(sessionReplay.isCapturing, isFalse);
          expect(viewsWithReplay, firstViews.toSet());
        });

        test('renewal into a sampled session starts recording', () async {
          final sessionReplay =
              await startSessionReplay(rumSampleRate: 50, replaySampleRate: 50);
          playSession(replayNotSampled);
          expect(sessionReplay.isCapturing, isFalse);

          renewInto(sampled);
          final renewedViews = playSession(sampled);

          expect(sessionReplay.isCapturing, isTrue);
          expect(viewsWithReplay, renewedViews.toSet());
        });

        test('the decision holds for every view of a session', () async {
          final sessionReplay =
              await startSessionReplay(rumSampleRate: 50, replaySampleRate: 50);

          final sampledViews = playSession(sampled);
          expect(sessionReplay.isCapturing, isTrue);
          expect(viewsWithReplay, sampledViews.toSet());

          renewInto(replayNotSampled);
          playSession(replayNotSampled);
          expect(sessionReplay.isCapturing, isFalse);
          expect(viewsWithReplay, sampledViews.toSet());
        });

        test('stopRecording() before renewal stays in effect after it',
            () async {
          final sessionReplay =
              await startSessionReplay(rumSampleRate: 50, replaySampleRate: 50);
          playSession(sampled);

          sessionReplay.stopRecording();
          renewInto(otherSampled);
          playSession(otherSampled);

          expect(sessionReplay.isCapturing, isFalse);
        });

        test('a session RUM does not sample, then a sampled one', () async {
          final sessionReplay =
              await startSessionReplay(rumSampleRate: 50, replaySampleRate: 50);
          renewInto(null);
          expect(sessionReplay.isCapturing, isFalse);

          renewInto(sampled);

          expect(sessionReplay.isCapturing, isTrue);
          expect(viewsWithReplay, {'$sampled/view-0'});
        });
      });
    }
  });

  group('embedded (hybrid) Session Replay', () {
    for (final rate in [0.0, 10.0, 20.0, 50.0, 100.0]) {
      test(
          'Flutter replaySampleRate $rate is ignored, every RUM session '
          'records', () async {
        final recorded = await recordedSessions(
          rumSampleRate: 100,
          replaySampleRate: rate,
          isEmbedded: true,
        );

        expect(recorded, sessionIds.toSet());
      });
    }

    // Flutter's own rate is 0 so that any replay proves it was ignored. The
    // native host samples the same session IDs at RUM x host rate, and the
    // replay has Flutter content only where Flutter recorded too.
    for (final rumRate in [0.0, 10.0, 50.0]) {
      for (final hostRate in [0.0, 10.0, 20.0, 50.0, 100.0]) {
        test(
            'RUM $rumRate% x host replay $hostRate% records Flutter content '
            'in exactly the sessions the host samples', () async {
          final hostSampled = sampledSessions(rumRate, hostRate);
          final flutterRecorded = await recordedSessions(
            rumSampleRate: rumRate,
            replaySampleRate: 0,
            isEmbedded: true,
          );

          expect(flutterRecorded.intersection(hostSampled), hostSampled);
        });
      }
    }
  });
}
