# Datadog Flutter Plugin - Session Replay Example

This example shows two Session Replay features:

* **Sampling with `replaySampleRate`**: only a percentage of RUM sessions get a
  replay.
* **Manual start and stop**: record only the screens you choose, using
  `startRecordingImmediately: false`, `startRecording()`, and `stopRecording()`.

## Setup

Generate the local `.env` file before running this example:

```bash
../../generate_env.sh
flutter run
```

Runtime credentials come from `.env`, which is ignored by git. Do not commit
real client tokens or application IDs.

## Sampling

`replaySampleRate` is the percentage of RUM sessions that get a replay. The
decision is made for each RUM session from its ID, so it is re-evaluated when
a new session starts during the same launch (after 15 minutes of inactivity,
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
