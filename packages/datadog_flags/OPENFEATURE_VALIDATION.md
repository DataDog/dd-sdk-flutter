# OpenFeature validation and feedback

This document records local validation for [Datadog PR #1134](https://github.com/DataDog/dd-sdk-flutter/pull/1134).
The canonical provider is `DatadogOpenFeatureProvider` in `datadog_flags`.
OpenFeature is the application API. The legacy evaluation API remains available
with deprecation notices until the next major version.

## Source and reproduction

- Base: `develop` at `c9d88cfa1843b316b72d668e86057d908f095322`.
- SDK and contract: `open-feature/dart-sdk` at `c57c285590ab87088cdc116cdb804adf6acab2a4`.
- The immutable `development` pin includes the Dart 3.10 minimum (#168),
  reconciliation event ordering (#192), and provider contract v2 (#193).
  At validation time, `main` at `5c774eca8f644c9282747ebf37ad35e6404b7d70` still lacks #192 and #193.
- Provider commit and tree: recorded by the receipt command below. Run it from a clean checkout after committing changes.

From the repository root, run:

```sh
cd packages/datadog_flags
dart pub get
dart analyze --fatal-infos
dart test --reporter expanded
dart test --platform chrome test/datadog_openfeature_provider_test.dart test/shared_contract_test.dart
dart test --platform chrome --compiler dart2wasm test/datadog_openfeature_provider_test.dart test/shared_contract_test.dart
cd ../..
python3 tools/ci/run_openfeature_contract.py --platform vm
python3 tools/ci/run_openfeature_contract.py --platform chrome
python3 tools/ci/test_openfeature_example.py --platform android
python3 tools/ci/test_openfeature_example.py --platform ios
```

Use Dart 3.10.0 for the minimum-version run. Set `CHROME_EXECUTABLE` if Chrome is
not discoverable. Boot one simulator for each native command, or pass `--device`.
The receipt helper uses the Git checkout that Dart actually resolved. It records
the SDK, contract, provider identity, dependency paths, and C01–C13 outcomes.
CI archives these receipts and native example logs under `.build/`.

## Local results

| Surface | Result | Scope |
| --- | --- | --- |
| Dart 3.10.0 VM | 116 tests passed; analysis passed | Core transport, telemetry, cache, provider, and C01–C13 |
| Chrome JavaScript on Dart 3.10.0 | 40 tests passed | Provider regressions and C01–C13 |
| Chrome WebAssembly on Dart 3.10.0 | 40 tests passed | Provider regressions and C01–C13 |
| Flutter 3.44.1 wrapper | 16 tests passed; analysis passed | Legacy lifecycle compatibility and RUM hook |
| Android API 36 emulator | Example integration test passed | Actual example UI, five types, defaults, refresh, identity, telemetry routes, shutdown |
| iOS 26.5 simulator | Example integration test passed | Same example and assertions on iPhone 17 Pro |

These runs use the real provider with controlled HTTP responses. Native tests
start the Datadog Flutter SDK with consent disabled and synthetic credentials.
They do not establish live Datadog connectivity or delivery to a RUM backend.
The RUM hook has a separate unit test. These local results do not replace CI.

## Review findings addressed

| Aaron's feedback | Result |
| --- | --- |
| Publish assignments before cache writes finish | Preserved the merged core fix; added provider coverage for a blocked write |
| Keep the provider deadline below the SDK lifecycle timeout | Reject null, disabled, and greater-than-20-second budgets before transport starts |
| Describe stale state accurately | Document pending or failed refresh; preserve usable cached assignments |
| Fence shutdown and superseded work | Check context revisions after asynchronous setup and cleanup; test direct races and repeated shutdown |
| Replace mutable dependency overrides and false publication evidence | Pin SDK and contract to one full commit; block publication until a hosted release is validated |
| Add missing cache, timer, and event regressions | Cover cached timeout, pending refresh cleanup, status deduplication, and late result rejection |
| Remove the fragile 5 ms reconciliation deadline | Use a larger controlled deadline and bounded condition waits |
| Prevent reuse of a client with a closed status stream | Make legacy shutdown terminal; `sharedClient()` returns a new client |
| Explain failed reconciliation versus initial recovery | Discard late failed-reconciliation results; allow initial late success to emit ready |
| Centralize metadata constants | Share constants between the core resolver and provider |
| Leave changelog generation to the release process | Removed the manual entry during the base merge |
| Demonstrate RUM integration | Add `DatadogRumHook` and use it in both Flutter examples |
| Resolve Flutter delegates once and fence late readiness | Share pending resolution; release delegates that arrive after shutdown |

Provider-specific metadata remains `datadog.allocation_key` and
`datadog.serial_id`, with provider name `Datadog`. These names differ from the
Android provider. Cross-SDK naming alignment and an `extraLogging` equivalent
remain design follow-ups. The duplicate example site mapping remains explicit
because the standalone provider and native Flutter plugin use different enums.

## Feedback for the OpenFeature maintainers

1. Datadog can run all thirteen shared v2 scenarios with its real provider and controlled transport.
   VM and Chrome receipts provide the exact source identities and package paths.
   The fixture declares same-instance reinitialization support.
   Separate native tests exercise the application on Android and iOS.
2. Cached context reconciliation exposed an event-ordering issue in the previous SDK pin.
   A provider emits `contextChanged`, then `stale`, before its callback returns.
   Upstream [#192](https://github.com/open-feature/dart-sdk/pull/192) fixes this ordering.
   The provider no longer defers the stale event. Its regression test checks
   stale status immediately after context reconciliation completes.
3. Upstream [#193](https://github.com/open-feature/dart-sdk/pull/193) adds direct
   provider shutdown, uninitialized evaluation state, and status-transition checks.
   Datadog retains separate tests for timer cleanup, direct context races, and late responses.
4. `HookAdapter` supports the RUM integration without API changes.
5. Validate a hosted release with these fixes and the Dart 3.10 floor before publishing Datadog's integration.
   Both Flags packages currently use `publish_to: none` and the immutable Git pin.

No upstream acceptance is implied. The receipt deliberately leaves
`independent_provider_gate_satisfied` false until maintainers review provenance,
transport evidence, platform coverage, and independent ownership.

The provider uses a configured static Datadog client token. It has no token
acquisition or automatic token-renewal mechanism. HTTP failure, timeout,
late recovery, cache isolation, and stale-response rejection have local tests.
Live service validation, operating-system suspend/resume, and physical-device
testing remain outside this evidence set. The event-order and contract findings
were addressed in upstream #192 and #193.
