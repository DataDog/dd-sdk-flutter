# OpenFeature validation and feedback

This document records local validation for [Datadog PR #1134](https://github.com/DataDog/dd-sdk-flutter/pull/1134).
The canonical provider is `DatadogOpenFeatureProvider` in `datadog_flags`.
OpenFeature is the application API. The legacy evaluation API remains available
with deprecation notices until the next major version.

## Source and reproduction

- SDK: published `openfeature_dart_client_sdk` version `0.0.1` from pub.dev.
- SDK archive SHA-256: `f94267788a0c1e1970c0d399f7e8066fe606f526dafb6e283e72e0f260b7f295`.
- Shared contract: `open-feature/dart-sdk` at the 0.0.1 release commit,
  `f8068cd5c71c6f644e1f69e171918de771e621c3`.
- The hosted runtime matches the release's `lib/` sources and includes the Dart
  3.10 minimum (#168), reconciliation event ordering (#192), contract v2 (#193),
  bounded contract initialization observation (#204), and initialization event
  replay/status ordering (#205).
- The unpublished contract harness has a relative SDK dependency. The core
  package overrides that dependency to the exact hosted release for testing only.
  The examples resolve the hosted SDK without an OpenFeature override.
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
The receipt helper checks the resolved SDK's hosted source, version, archive
hash, and runtime files against the release. It separately identifies the Git
contract checkout and provider tree, dependency paths, and C01–C13 outcomes.
CI archives these receipts and native example logs under `.build/`.

## Hosted 0.0.1 results

These local checks were run on October 6, 2026 after merging `develop` at
`f2e4deb73f8f28578c74bd0571efbb90cace5b4d`. The receipt files record the
exact provider commit/tree; use clean-checkout receipts for published evidence.

| Surface | Result | Scope |
| --- | --- | --- |
| Dart 3.10.0 VM | 124 tests passed; analysis and formatting passed | Full core suite shuffled with seed 1134; includes merged cache behavior |
| Chrome JavaScript on Dart 3.10.0 | 47 tests passed; compile smoke passed | Provider, C01–C13, and evaluation telemetry |
| Chrome WebAssembly on Dart 3.10.0 | 47 tests passed | Same provider, contract, and telemetry coverage |
| Shared contract receipts | C01–C13 passed on VM and Chrome | Hosted archive and release runtime verified; receipts record provider identity |
| Flutter 3.44.0 wrapper | 17 tests passed; analysis passed | RUM hook and legacy lifecycle/cache compatibility |
| Consumer examples | Dependency resolution and analysis passed | Dart CLI and both Flutter examples resolve hosted 0.0.1 without an OpenFeature override |
| Shared example widget | Small-screen refresh regression passed | Scrolls until the lazy list builds the refresh button, then invokes refresh |
| Hosted dependency helpers | 10 tests passed | Reject beta versions, non-hosted sources, wrong archives, and replaced runtime sources |
| Release helper | 6 tests passed; analysis passed | Retains only the matching hosted contract SDK override; removes local and Git overrides |

The provider cache regression checks `CACHED` while restored assignments are
served and `TARGETING_MATCH` after network recovery. Android's previous failure
was an off-screen, unbuilt refresh button; the test now scrolls before tapping.
iOS failed before launch because the prior `main` merge brought release-only
native pins into this development branch. Native dependency configuration is
restored to `develop`; no unrelated package minimum has changed.

These are local, controlled-transport results, not new native or live-service
acceptance. The updated Android and iOS CI jobs must pass on the final PR head.

## Release gates

Both Flags manifests now permit publication. This does not publish either package.
Before releasing:

1. Require green CI on the final head and maintainer approval. Existing review
   threads remain for reviewers to verify; implemented fixes are not approval.
2. Run the normal release preparation to generate the 1.2.0 changelogs. Raw
   publication dry runs warn until those entries exist. Do not hand-maintain
   them in this feature PR.
3. Preserve the core's exact hosted OpenFeature override for the development-only
   upstream contract harness. Removing it causes a hosted-versus-Git dependency
   conflict. The release helper retains this narrowly matched override while
   removing other local overrides. Customers do not inherit it.
4. Publish `datadog_flags` 1.2.0 first. Then validate `datadog_flags_flutter` 1.2.0
   against that hosted core without local Datadog overrides and publish it. A
   dry run using Melos overrides is not proof of hosted consumer resolution.
5. Finish live-service acceptance and publish the customer documentation and
   migration guidance with the packages. Physical devices and operating-system
   suspend/resume have not been validated by the local evidence above.

## Historical hosted beta.2 results

The core and browser runs below use provider commit
`34136500a3721886b809169180684804b6d70cf6`, after merging `main` at
`331f08b6638ad39203d6de16941b723b88495a9d` and `develop` at
`29ddec14c3792a9ec197a398ad000b683a6ab759`.

| Surface | Result | Scope |
| --- | --- | --- |
| Dart 3.10.0 VM | 116 tests passed; analysis and formatting passed | Full core suite, including randomized order with seed 1134 |
| Chrome JavaScript on Dart 3.10.0 | 47 tests passed | Provider, C01–C13, and web evaluation metadata |
| Chrome WebAssembly on Dart 3.10.0 | 47 tests passed | Same provider, contract, and telemetry tests |
| Shared contract receipts | C01–C13 passed on VM and Chrome | Clean provider/contract trees; hosted archive and release runtime verified |
| Flutter 3.44.0 wrapper | 16 tests passed; analysis passed | RUM hook, duplicate resolution, late initialization, and shutdown |
| Consumer examples | Dependency resolution passed | Dart CLI and both Flutter examples use hosted beta.2 without an OpenFeature override |
| Hosted dependency helpers | 10 tests passed | Archive/source checks, runtime comparison, and Melos-generated override handling |

The previously order-sensitive failed-reconciliation test also passes alone and
in the 27-test provider suite shuffled with seed 2993. The shared Flutter example
passes analysis with a local credential-free `.env` asset. These are local tests
with controlled transport; Android/iOS runtime and live-service validation were
not repeated for this update. Package publishing remains disabled.

## Earlier source-pin results

These results predate the hosted beta.2 update and used SDK/contract commit
`c57c285590ab87088cdc116cdb804adf6acab2a4`. They are retained as historical evidence,
not as new native-platform validation of the hosted release.

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
| Replace mutable dependency overrides and false publication evidence | Use hosted 0.0.1 for runtime and tests; verify its archive and runtime sources; pin only the development harness to the release commit |
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
   VM and Chrome receipts identify the hosted SDK, contract checkout, and package paths.
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
5. Runtime dependencies now use the published 0.0.1 release, including the
   initialization event/status ordering fix in [#205](https://github.com/open-feature/dart-sdk/pull/205).
   Publication blocks are removed, but normal release preparation and approval
   are still required. Only the development harness uses a Git pin.

No upstream acceptance is implied. The receipt deliberately leaves
`independent_provider_gate_satisfied` false until maintainers review provenance,
transport evidence, platform coverage, and independent ownership.

The provider uses a configured static Datadog client token. It has no token
acquisition or automatic token-renewal mechanism. HTTP failure, timeout,
late recovery, cache isolation, and stale-response rejection have local tests.
Live service validation, operating-system suspend/resume, and physical-device
testing remain outside this evidence set. The event-order and contract findings
were addressed in upstream #192 and #193.
