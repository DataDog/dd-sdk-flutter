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

Next, we need to generate some necessary files with `flutter pub run build_runner build`, 
and generate `.env` files for the various apps in order to use them with
Datadog. We use Melos for this as well. Run:

```bash
melos prepare
```

Running `melos prepare` creates `.env` files in the various example application,
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

Before submitting a PR, you can run all of these steps, as well as all
integration tests, by running the `./preflight.sh` script in the root of the
repo. Using this script requires you have both
[Swiftlint](https://github.com/realm/SwiftLint) and [Bitrise
CLI](https://app.bitrise.io/cli) available on your path

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
