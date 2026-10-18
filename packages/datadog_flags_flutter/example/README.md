# Flags integration example

This example owns the Flags and RUM integration tests. The core plugin test app
does not depend on either Flags package.

Bootstrap the local packages with Melos before running the example.
Generate a runner for the platform under test:

```sh
flutter create --empty --no-pub --platforms=ios .
cp integration_test/Podfile ios/Podfile
flutter pub get
flutter test integration_test/evaluation_telemetry_opt_out_test.dart -d <device>
```

Use `android` for an Android device. Generated platform runners are not committed.
For Android, copy `integration_test/AndroidManifest.xml` to
`android/app/src/debug/AndroidManifest.xml` to allow the local HTTP test server.
The repository's iOS and Android integration commands run this setup automatically.

The mobile test uses the shared `datadog_common_test` recording server.
Only assignment responses are stubbed. Flags evaluations, exposures, and native
RUM events go through their real upload paths to the recording server.
The Web intake test uses the same server through the standard integration driver.

The portable contract tests run without a device:

```sh
cd ../../..
melos run unit_test:flags_web
```

This runs the core and Flutter wrapper opt-out tests in Chrome with both
JavaScript and WebAssembly. The VM-only HTTP smoke test checks real sockets
separately in the core package.
