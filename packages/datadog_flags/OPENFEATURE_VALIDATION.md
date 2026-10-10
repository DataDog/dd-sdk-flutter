# OpenFeature validation

Run these checks when changing the Datadog provider, its lifecycle behavior,
or the OpenFeature dependency. Use the repository's Flutter toolchain.
For the minimum-version run, use FVM with Flutter 3.38.0 and its Dart 3.10 SDK.

## Package tests

From the repository root:

```sh
cd packages/datadog_flags
dart pub get
dart analyze .
dart test
dart test --platform chrome
dart test --platform chrome --compiler dart2wasm
cd ../datadog_flags_flutter
flutter pub get
flutter analyze
flutter test
```

Melos bootstrap links local Datadog packages. Use it before testing Flutter
packages against unpublished local changes. The VM-only fixture-file tests
use `@TestOn('vm')`; all other core tests run in browser discovery.

## Upstream provider contract

The separate `tools/openfeature_conformance` package runs C01–C13 from the
upstream client-provider contract. It uses the real Datadog provider with
controlled HTTP responses. The SDK is the hosted `0.0.1` release. The harness
is pinned to that release commit, `f8068cd5c71c6f644e1f69e171918de771e621c3`.

```sh
cd tools/openfeature_conformance
dart pub get
dart analyze .
dart test
dart test --platform chrome
dart test --platform chrome --compiler dart2wasm
```

The harness depends on its SDK source checkout. An override in this test package
selects the hosted SDK instead. Published Datadog packages have no OpenFeature
override and do not depend on the harness. The normal release tool needs no
contract-specific behavior.

When reporting results upstream, record the provider commit, contract commit,
SDK version, lockfile archive hash, Dart version, and test command. Retain the
JSON test output from `dart test --reporter json` and the dependency list from
`dart pub deps --json`. Run from a clean checkout and identify the platform.
CI retains its normal JUnit reports. Passing controlled-transport tests does
not establish live-service delivery or upstream maintainer acceptance.

## Native integration

Boot an Android emulator or an iOS simulator, then run:

```sh
cd packages/datadog_flutter_plugin/datadog_flutter_plugin/integration_test_app
flutter pub get
flutter test integration_test/openfeature_test.dart -d <DEVICE_ID>
```

The dedicated integration app covers typed values, defaults, refresh, identity
changes, telemetry requests, and shutdown. It uses synthetic credentials and
controlled HTTP responses. Tracking consent is disabled for the native SDK.
The test does not verify live Datadog connectivity or RUM delivery.
The standard Android and iOS integration jobs discover this test automatically.

Keep customer examples focused on initialization and evaluation. Integration
test setup and controlled transports belong in the integration test app.

## Release checks

Use the normal release process and generated changelogs. Publish `datadog_flags`
before the Flutter integration package, then validate the Flutter package against
the hosted core. Local Melos overrides are not proof of hosted consumer resolution.

Provider metadata uses `datadog.allocation_key`, `datadog.serial_id`, and the
provider name `Datadog`. Cross-SDK naming alignment and `extraLogging` forwarding
remain separate design decisions.
