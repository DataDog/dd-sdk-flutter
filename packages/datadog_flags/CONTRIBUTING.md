<!--
Unless explicitly stated otherwise all files in this repository are licensed
under the Apache License Version 2.0. This product includes software developed
at Datadog (https://www.datadoghq.com/). Copyright 2019-Present Datadog, Inc.
-->

# Contributing

Follow the repository-level CONTRIBUTING.md for general package guidance.

From this package, the focused local checks are:

```bash
dart analyze .
dart test
dart test --platform chrome
```

The typed evaluation example can run against Datadog:

```bash
cd example
DD_CLIENT_TOKEN=<client-token> \
dart run datadog_flags_example:typed_evaluation \
  --env staging \
  --flag-key checkout.enabled \
  --flag-type boolean \
  --targeting-key test-subject
```

## Obfuscated assignments

The SDK advertises `assignment-encoding-flag-key-256-v1` in the
`X-DD-FEATURE-FLAGS-CAPABILITIES` header for Datadog endpoints.
Custom endpoints receive this header only when explicitly configured.

Responses with `obfuscated: true` use the `flag-key-sha256-v1` scheme.
The SDK hashes the domain prefix `datadog.feature-flags.flag-key.v1\0`, decoded
salt bytes, and the original flag key's UTF-8 bytes, in that order, with SHA-256.
It does not normalize the flag key. Malformed Unicode keys return `FLAG_NOT_FOUND`.
Each encoding descriptor caches up to 1,024 lookup hashes, not flag values.

`json_serializable` reads and writes the descriptor's `scheme` and `salt` fields.
Validation rejects unsupported schemes, malformed salts, and inconsistent
encoding metadata. Unknown JSON fields remain supported.
Regenerate the serialization code after changing the descriptor:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Encoded snapshots store their assignments under `encodedFlags`, together with
their encoding descriptor. Plaintext snapshots use `flags` and remain readable.
Older SDKs cannot use an encoded snapshot after a downgrade. They return defaults
until a successful plaintext network response provides assignments.
Invalid encoding metadata follows the normal initialization failure path.
Valid stored assignments remain available only for the same evaluation context.

## OpenFeature validation

Run these checks when changing the Datadog provider, its lifecycle behavior,
or the OpenFeature dependency. Use the repository's Flutter toolchain.
For the minimum-version run, use FVM with Flutter 3.38.1 and stable Dart 3.10.0.

### Package tests

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

### Upstream provider contract

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

### Native integration

Boot an Android emulator or an iOS simulator, then run:

```sh
cd packages/datadog_flags_flutter/integration_test_app
flutter pub get
flutter test integration_test/openfeature_test.dart -d <DEVICE_ID>
```

The Flags package owns the dedicated integration app. It covers typed values, defaults, refresh, identity
changes, strict/default context switching, direct Dart callers, telemetry requests,
and shutdown. It uses synthetic credentials and
controlled HTTP responses. Tracking consent is disabled for the native SDK.
The test does not verify live Datadog connectivity or RUM delivery.
The standard Android, iOS, desktop, and web integration jobs discover this app.

Keep customer examples focused on initialization and evaluation. Integration
test setup and controlled transports belong in the integration test app.

### Release checks

Use the normal release process and generated changelogs. Publish `datadog_flags`
before the Flutter integration package, then validate the Flutter package against
the hosted core. Local Melos overrides are not proof of hosted consumer resolution.
