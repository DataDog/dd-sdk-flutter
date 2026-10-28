# Repository Instructions

## Dart language

- Follow [Effective Dart](https://dart.dev/effective-dart).
- Read the `environment.sdk` constraint in the `pubspec.yaml` of the package you are
  editing, and use every language feature that constraint allows. Do not raise an SDK
  or Flutter constraint to use a newer feature; raising one is a separate, deliberate change.
- Prefer, where they simplify the code:
  - Enhanced enums with fields, factories, and methods, instead of free `switch`
    helpers or `Map` lookups next to an enum.
  - Extension methods or extension types instead of private static helpers.
  - Patterns and `case` bindings (`if (x case final y?)`) instead of `!` or manual casts.
  - Collection `for` / `if` instead of `.map(...).toList()` in list literals and widget children.
  - Cascades, `typedef`s for function types, and optional *named* parameters.
- Mark data classes `@immutable` and `final class`. Use records only when a named
  class would be heavier.
- Avoid static mutable state; hold state on instances.
- Do not add a file for each small type. Group related types.
- Prefer simple async constructs (`Future.any`, cancel tokens, one in-flight operation)
  over request IDs, polling stopwatches, or overlapping timers.

## JSON

- Use `json_serializable` (`dart run build_runner build`) for JSON models. Do not
  hand-write `fromJson` / `toJson` or index into nested `Map`s. See
  `datadog_flutter_plugin_platform_interface/lib/src/rum/ddrum_events.dart` and
  `datadog_flags` for examples.
- Re-running `build_runner` must leave no diff.

## Client SDK behavior

- Public SDK APIs must not throw on misconfiguration or runtime failure. Log a warning
  or error and leave the SDK in a valid state.

## Docs and comments

- Never edit `CHANGELOG.md`, `.release/`, or version files. The releaser generates them.
- A package `README.md` is public, customer-facing documentation. Do not put contributor
  instructions, validation notes, or implementation detail in it. Contributor content goes
  in `CONTRIBUTING.md`; API detail goes in dartdoc, linking symbols with `[name]`.
- Comments say briefly what the code does. Do not describe what it doesn't do.
- Comments and docs describe how the code currently works, not how it changed or what it
  replaced. Do not write "previously X, now Y", "no longer does X", "instead of X", or
  similar history. Mention an alternative approach only to justify a deliberate deviation
  from a standard or obvious one, and keep it brief.

## Examples

- Examples show minimal SDK usage. Do not add test hooks, dogfooding features, or other
  scaffolding. Dogfooding apps go in `test_apps`.
- Read configuration from the `.env` files that `melos generate_env` produces, not
  `String.fromEnvironment`.

## Tests

- Generate one `test(...)` per case in a loop instead of one test over all cases.
- Declare shared fixtures inside `main` or the `group`, not at file scope.
- Use `mocktail` for fakes and mocks. Do not add helpers whose only job is to return a
  prebuilt object.
- Do not test the compiler (enum values, constructors), the examples, or use VM-internal
  APIs such as forcing GC.
- Locate fixture files without relying on the working directory
  (`Isolate.resolvePackageUri`).
- Packages that support Web / WASM need tests that run there. Avoid `@TestOn('vm')`
  unless the test covers a VM-specific feature or one that is not available on web.
- Integration tests live in the owning package's example app, using `datadog_common_test`.
  Do not add them to `datadog_flutter_plugin/integration_test_app`.
- Do not send real events to intake from tests; it affects billing.

## Tooling

- Write repo scripts in Dart. Simple scripts can be bash where appropriate.
- Run `dart test` rather than naming test files. Do not add publish targets to `melos.yaml`.
- Do not add `dependency_overrides` unless the build fails without them.
- Use lower-bound-only constraints for dev dependencies (for example `lints: '>=5.0.0'`);
  nightlies run minimum-version checks.
- Before opening a PR, run `melos dartfmt_check`, `melos analyze:dart`, and
  `melos unit_test:flutter`. See [CONTRIBUTING.md](CONTRIBUTING.md#code-style) for the
  native and integration test scripts.

## Commit messages

- Follow the [commit message guide](CONTRIBUTING.md#commit-messages).
- Use a Conventional Commit for the main change before requesting review.
- Review follow-up commits can use descriptive subjects without this format.
- Do not amend, rebase, or force-push only to repair a commit subject.
