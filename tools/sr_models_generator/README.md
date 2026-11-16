# sr_models_generator

Generates the Dart Session Replay data models of `datadog_session_replay`
from the JSON schemas in
[rum-events-format](https://github.com/DataDog/rum-events-format).

> **Status:** work in progress. The command-line entry point exists, but it
> does not generate anything yet.

## Why

The Session Replay models are written by hand today
(`packages/datadog_session_replay/lib/src/sr_data_models.dart`), while
dd-sdk-ios and dd-sdk-android generate theirs from rum-events-format. 
Hand-written models drift from the schema: types the schema defines 
(embedded content wireframes, shape gradients, composition tree, view 
end and visual viewport records, ...) are missing in Flutter, and every 
schema change has to be ported manually.

## Design

* **Single reference to rum-events-format.** The repository keeps only the
  pinned rum-events-format commit (in a config file next to this README).
  The schemas are fetched at that commit when generating and are never
  committed.
* **Dart-native.** The generator is a plain Dart package, so it runs with
  `dart run` on any CI host, with no Swift or Kotlin toolchain.
* **Fail loudly.** JSON Schema features outside the subset rum-events-format
  uses make the generator stop with an error instead of emitting approximate
  code.

## Usage

```sh
dart pub get
dart run sr_models_generator --help
```
