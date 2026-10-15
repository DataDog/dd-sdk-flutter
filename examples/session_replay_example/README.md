# Datadog Flutter Plugin: Session Replay example

This example shows two Session Replay features:

* **Sampling with `replaySampleRate`**: Only a percentage of RUM sessions get a
  replay.
* **Manual start and stop**: Recording covers only the screens you choose, with
  `startRecordingImmediately: false`, `startRecording()`, and `stopRecording()`.

## Setup

Generate the local `.env` file, then run this example:

```bash
../../generate_env.sh
flutter run
```

Runtime credentials come from `.env`, which is ignored by Git. Do not commit
real client tokens or application IDs.

## Sampling

`replaySampleRate` is the percentage of RUM sessions that get a replay. The
decision is made for each RUM session from its ID, so it is re-evaluated when
a new session starts during the same launch (after 15 minutes of inactivity
or after 4 hours). The same session ID always gets the same decision, on every
Datadog SDK.

The rate stacks on the RUM `sessionSamplingRate`, because Session Replay can
only record sessions that RUM tracks. This example sets both to 50%, so about
25% of all sessions have a replay. Restart the app a few times to see some
sessions recorded and others not.

To try a different Session Replay rate, add this line to `.env`:

```dotenv
DD_SESSION_REPLAY_SAMPLE_RATE=100
```

While the current session is not selected, `startRecording()` has no effect
and the Recorded screen shows "NOT recorded". Recording starts on its own when
a sampled session begins.

## Manual start and stop

The app is configured with `startRecordingImmediately: false`, so nothing is
recorded until it calls `startRecording()`:

* **Recorded screen** calls `DatadogSessionReplay.instance?.startRecording()`
  when it is shown.
* **Private screen** calls `DatadogSessionReplay.instance?.stopRecording()`
  when it is shown, so nothing on it is captured, including touches.

Switch between the two tabs and the status at the top of each screen follows
`DatadogSessionReplay.instance?.isCapturing`. In the replay, the Private screen
does not appear, and recording resumes when you return to the Recorded screen.

## Sampling test

`scripts/run_sampling_test.sh` checks Session Replay sampling end to end on
an iOS simulator or an Android emulator. It launches the app many times (100
by default). In each launch, the app taps through its screens for about 10
seconds, then logs its RUM session ID, whether that session should get a
replay, and whether Session Replay captured. It doesn't use the host mouse or
keyboard, and starts the simulator or emulator headless if it isn't running.

```bash
scripts/run_sampling_test.sh -b              # iOS: build, install, run 100 launches
scripts/run_sampling_test.sh -p android -b   # Android: same, on an emulator
scripts/run_sampling_test.sh -n 50 -r my-run # 50 launches with a custom run ID
```

For Android, the script finds the SDK through `ANDROID_HOME` (or
`~/Library/Android/sdk`) and uses the first running device, or else boots the
first AVD.

At the end, it prints a summary and writes the exact list of sessions that
should have a replay to `/tmp/sr_sampling/<run id>/`. To compare with
Datadog, filter RUM sessions on `@sr_test_run:<run id>`.

The test mode lives in `lib/auto_interact.dart` and does nothing unless the
script enables it, so the app behaves normally otherwise.
