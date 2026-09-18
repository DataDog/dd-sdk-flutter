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
