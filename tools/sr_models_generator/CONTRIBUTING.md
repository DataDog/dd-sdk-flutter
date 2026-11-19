# Contributing to sr_models_generator

## Why

The Session Replay models are written by hand today
(`packages/datadog_session_replay/lib/src/sr_data_models.dart`), while
dd-sdk-ios and dd-sdk-android generate theirs from rum-events-format.
Hand-written models drift from the schema: types the schema defines
(embedded content wireframes, shape gradients, composition tree, view end
and visual viewport records, ...) are missing in Flutter, and every schema
change has to be ported manually.

## Design

* **Single reference to rum-events-format.** The repository keeps only the
  pinned rum-events-format commit, in `sr_models_generator.yaml`. The schemas
  are fetched at that commit when generating, into `.dart_tool/`, and are
  never committed.
* **Dart-native.** The generator is a plain Dart package, so it runs with
  `dart run` on any CI host, with no Swift or Kotlin toolchain.
* **Fail loudly.** JSON Schema keywords outside the subset rum-events-format
  uses make the generator stop with an error, naming the schema file and
  position, so that no type is generated without part of its schema.

## Naming

Types are named `type_prefix` + the schema title without the words in
`strip_from_titles` (`MobileSegment` -> `SRSegment`), and schemas without a
title after their owner and property (`SRMetaRecord` + `data` ->
`SRMetaRecordData`).

`type_renames` in `sr_models_generator.yaml` keeps the names of the
hand-written Flutter models. A rename's key is a generated name, or a schema
location (`file#pointer`, as error messages print it) to rename a single
schema. A rename that matches nothing is an error.

## Tests

```sh
dart test
```

The tests tagged `rum-events-format` resolve the real schemas at the pinned
commit; their first run downloads it into `.dart_tool/`. To skip them:

```sh
dart test -x rum-events-format
```
