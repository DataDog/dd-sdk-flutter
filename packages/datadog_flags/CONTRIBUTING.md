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
