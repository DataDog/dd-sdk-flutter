# Contributing

First of all, thanks for contributing!

This document provides some basic guidelines for contributing to this
repository. To propose improvements, feel free to submit a PR or open an Issue.

**Note:** Datadog requires that all commits within this repository must be signed, including those within external contribution PRs. Please ensure you have followed GitHub's [Signing Commits](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits) guide before proposing a contribution. PRs lacking signed commits will not be processed and may be rejected.

## Found a bug?
For any urgent matters (such as outages) or issues concerning the Datadog
service or UI, contact our support team via https://docs.datadoghq.com/help/ for
direct, faster assistance.

You may submit a bug report concerning the Datadog Plugin for Flutter by opening
a GitHub Issue. Use appropriate template and provide all listed details to help
us resolve the issue.

## Getting started?

Make sure you have installed the [Flutter
SDK](https://docs.flutter.dev/get-started/install), and that `flutter doctor`
passes without issues.

The Datadog packages use [Melos](https://github.com/invertase/melos) to manage
the complexities of the monorepo. To start with the repo, run the following command:

```bash
dart pub global activate melos
```

Next, at the root of the repository, bootstrap melos:

```bash
melos bootstrap
```

Next, we need to generate necessary `dd.env` files for the various apps in order to use them with
Datadog. We use Melos for this as well. Run:

```bash
melos prepare
```

Running `melos prepare` creates `dd.env` files in the various example application,
which should be modified with your Client Id and Application Id from the Datadog
RUM setup. Alternately, it can pull this information from the environment
variables `DD_CLIENT_TOKEN` and `DD_APPLICATION_ID` for most test apps, and
`DD_E2E_CLIENT_TOKEN` and `DD_E2E_APPLICATION_ID` for the e2e test application.

If you need to switch environments frequently, you can use `melos generate_env` to
only generate the environment files, without re-running other prepare steps.

## Code Style

Code style is enforced with the following libraries in the following languages:

* Flutter - we use the included Flutter analyzer and linter. If you can, set up
  your IDE to format your Dart files on save, which will keep you in conformance
  with the linter
* iOS / Swift - [Swiftlint](https://github.com/realm/SwiftLint) is configured to
  run as part of the build in XCode. If you want Swiftlint to autoformat your
  files for you and fix any potential errors, run `swiftlint --fix`
* Android / Kotlin - We have both [ktlint](https://github.com/pinterest/ktlint)
  and [detekt](https://github.com/detekt/detekt) set up for static analysis and
  linting.

Before submitting a PR, run `melos dartfmt_check`, `melos analyze:dart`, and
`melos unit_test:flutter` from the root of the repo. If you changed native code,
also run `melos analyze:android` or `melos analyze:ios`. These skip `example`,
`integration_test_app`, and `e2e_test_app` packages, so build and check native changes
in those apps directly. Melos has further scripts
for the platform-specific linters (such as `melos lint_fix:ios`), other unit test
platforms (such as `melos unit_test:web`), and integration tests (such as
`melos integration_test:android`).

Dart code should follow [Effective Dart](https://dart.dev/effective-dart) and use
the language features available at the package's minimum SDK. See [AGENTS.md](AGENTS.md) for the
specific conventions we ask contributors and coding agents to follow.

### Version constraints

Each package's `pubspec.yaml` is the source of truth for its minimum Dart and
Flutter versions. Changes to those minimums are made deliberately and called out in
the PR. Dev dependencies use lower-bound-only constraints, because the nightlies run
minimum-version checks.

### Generated files

JSON models use `json_serializable`. After changing one, run
`dart run build_runner build` in the package and commit the generated files.
Running it again must not change any files.

## Package layout

* A package's `README.md` is the front page of its pub.dev documentation. Keep it
  customer-facing: no contributor instructions, validation notes, or implementation
  detail. Put contributor content here and API detail in dartdoc comments.
* A package's `example/` is a standalone app with its own `pubspec.yaml` that shows
  minimal SDK usage. Do not add testing hooks or dogfooding features to it.
* Dogfooding and test-bed apps live in `test_apps`.
* Integration tests for a package live in that package, in its `example/` or its own
  `integration_test_app/`, built on `datadog_common_test`.
  `datadog_flutter_plugin/integration_test_app` only tests `datadog_flutter_plugin`.

## Commit messages

Before requesting review, include at least one non-merge commit that uses the
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) format:

```text
<type>[optional scope][!]: <description>
```

For example, use `feat(flags): add initialization timeout` or
`fix(web): avoid duplicate requests`.

For features and bug fixes, use a `feat:` or `fix:` commit that changes the
relevant package. Such a commit makes the change eligible for the changelog. The
release tooling groups changes by pull request and writes the entries. An empty
commit does not appear in the package history used by the release tooling. Use types such as `docs:` or `chore:` for changes that do not
need changelog entries.

Review follow-up commits can use descriptive subjects without this format.
The Conventional Commit does not need to be the last commit. Avoid adding
`feat:` or `fix:` only to label review fixes for the same change. Do not rewrite
pushed history only to repair a commit subject.

For squash merges, ensure that the resulting commit subject also uses this
format. A Conventional Commit pull request title can supply that subject.
A pull request title does not change commit subjects preserved by merge or
rebase.

Do not add changelog entries in a pull request. The release tooling generates
the changelog from the Conventional Commit subjects.

## Tests

There are three types of tests in this repo

* Unit Tests (held in `test`) - These tests mostly check the logic of the
  platform_channel interfaces.
* Integration Tests (`integration_test_app/integration_test`) - These
  tests check that that calls to the SDK are sent to a mock server and match our
  expectations for the data that is getting sent to DataDog.
* E2E tests (held in `e2e_test_app/integration_test`) - These tests are still in
  progress, but they report information back to the Integration environment at
  Datadog, measuring that we send the correct number of events and monitor the
  performance of the SDK.

Any new PR must at least include unit tests, and hopefully include changes to
(or new tests) in the corresponding integration tests.

Test style:

* Generate one test per case rather than one test that loops over all cases, so
  each failure is reported separately.
* Use [mocktail](https://pub.dev/packages/mocktail) for fakes and mocks.
* Packages that support Web / WASM should have tests that run there.
* Do not add unit tests for example apps, and do not depend on VM internals such as
  forcing garbage collection.
* Tests that send events to Datadog intake can affect billing. Get a maintainer's
  sign-off before adding one.

## Reviews

You should be able to explain every change in your PR, including code written by
a coding agent.

Respond to or resolve every finding from automated reviewers (such as Codex or
Copilot) before requesting human review. Ask for a re-review if you make changes
in response to a human review.

## `develop` and `main`

Development in this repo occurs on the `develop` branch. The `develop` branch
works off of the latest code from most of the native repos (`dd-sdk-ios`, 
`dd-sdk-android`, and `dd-sdk-cpp`) so that we can catch potential incompatibilities
with those SDKs in real time.

When any package is released, `develop` is merged to `main` and all of the native
SDKs are pinned to the currently supported native releases. For this reason, `main` 
should be "Forward Only", as we do not want to bring these pins back into `develop`.
You should not, nor should you need to, merge changes from `main` back into `develop` 
or any development branch.

### Refreshing the `dd-sdk-ios` pin

On `develop`, the iOS plugin depends on the `develop` branch of `dd-sdk-ios`, but
SwiftPM records the resolved commit in `Package.resolved` (which is gitignored) and
keeps building it. Flutter also keeps a checkout in `build/ios/SourcePackages`. If an
example fails to build with errors about missing `dd-sdk-ios` symbols, it is possible
the pin is stale.

Deleting only `Package.resolved`, the SwiftPM cache, or Xcode's DerivedData does not
reliably fix this: the pins are regenerated from the checkout in `build/ios`. Run:

```
melos run reset:ios_packages
```

This deletes `build/ios/SourcePackages` and both `Package.resolved` files in every iOS
app, so the next `flutter run` or `flutter build ios` resolves `develop` again. To do it
for a single app, delete those three paths by hand.

## Trunk based development and patch releases

This repo mostly follows a "trunk based development" style, with `develop` being the
trunk. Minor releases are all released from `develop` and any patches and changes
should be created and merged on `develop`.

Previously, the repo put all releases on a long-lived `release/` branch, though this
practice is being deprecated. `release/` branches should only be created when a release
line is needed for a patch release,  such as a `release/3.6.x` line.

If a change is needed for a patch release, that change should **first be made on `develop`**,
then cherry-picked into its release line branch. The patch release can then be made from
this release line branch, and the changelog change cherry-picked back into `develop`.

## Shared precomputed response tests

The Flags module tests use a snapshot of the JSON contract from [ffe-system-test-data](https://github.com/DataDog/ffe-system-test-data/tree/main/precomputed-assignments).
The snapshot keeps response behavior consistent across mobile SDKs. It contains test data only.
It adds no runtime dependency and requires no Git submodule.

The snapshot is at `packages/datadog_flags/test/fixtures/precomputed`.
Its `SOURCE.json` records the source commit and file digests.
Each fixture is a JSON test case with a response, evaluations, and expected results.
The test runner (`packages/datadog_flags/test/precomputed_fixture_files_test.dart`) runs the fixtures from generated embedded text.
Snapshot generation discovers all nested JSON fixtures.
To add a fixture, change it upstream, refresh the snapshot, and regenerate the embedded text.
You do not need to change the test runner or maintain a filename list.
Missing fixtures or an empty snapshot fail verification.
The shared `_include` and `_skip` fields define platform applicability for fixtures, evaluations, and event expectations.
Do not add local exclusions to hide failures.

Numeric semantics follow the [shared contract](https://github.com/DataDog/ffe-system-test-data/blob/main/precomputed-assignments/README.md#mobile-conformance-and-numeric-types).

### Fixture coverage

A generated obfuscated companion is a fixture with encoded response-map keys and the same expected public results as its plain fixture.
Upstream CI requires a companion for each applicable plain fixture.
It rejects missing, stale, or orphaned companions.
Edit the plain fixture upstream, then regenerate its companion.
Dedicated malformed-encoding fixtures and fixed digest vectors are maintained separately from generated companions. They do not require plain-fixture counterparts.

Fixtures cover values, defaults, errors, reasons, variants, event emission conditions, duplicate evaluations, and numeric boundaries.
Obfuscation fixtures cover fixed digests, salts, Unicode, whitespace, malformed metadata, and plaintext event identity.

The fixture tests use the public client with a test HTTP transport.
They check the exposure and evaluation payloads it sends.
Each applicable fixture with a valid response also runs after JSON cache restoration.
The tests run the same embedded fixtures on VM, dart2js, and dart2wasm.
On dart2js, fixtures restricted to native Int64 values are reported as skipped.
Excluded evaluations and event expectations within a fixture are omitted without separate test results.
These tests do not cover the native bridge, which has separate tests.

### Run the fixture tests

To verify the snapshot and run the fixture tests, run the following from the repository root:

```sh
dart pub get
dart run ci/sync-precomputed-fixtures.dart --verify
dart ci/embed-precomputed-fixtures.dart --check
(cd packages/datadog_flags && dart test test/precomputed_fixture_files_test.dart)
```

### Refresh the snapshot

From the repository root, refresh the snapshot from a reviewed upstream commit:

```sh
dart pub get
dart run ci/sync-precomputed-fixtures.dart --ref <full-upstream-sha>
dart run ci/sync-precomputed-fixtures.dart --check
dart ci/embed-precomputed-fixtures.dart
```

The importer (`ci/sync-precomputed-fixtures.dart`) copies committed bytes, regenerates the fixture index, and removes deleted fixtures.
Do not edit imported JSON or its checksums.
Use `--source <local-checkout> --ref <commit>` to test an upstream fixture branch before publication.
`--verify` checks local integrity without networking. `--check` also compares the recorded upstream commit.

### Automatic fixture updates

The weekly `Precomputed flag fixtures` workflow opens a draft update PR when fixture content changes.
It uses a short-lived token restricted to the default branch and this workflow.
It waits when an update PR is already open. Normal SDK CI must pass before the update PR merges.
Merge the upstream fixture contract before merging its consumer PRs.
The update workflow never merges or publishes an SDK release.
