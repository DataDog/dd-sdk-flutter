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

## Response protection

`DatadogFlagsConfiguration.responseProtection` applies only to the precompute
assignment POST in `FlagAssignmentsFetcher`. Exposure and evaluation telemetry
keep the configured or default `http.Client`.

`ResponseProtection.tlsPinning` uses an SDK-owned client from
`assignment_transport.dart`. A conditional export selects the platform code:

- On Dart IO, `HttpClient.connectionFactory` opens a `SecureSocket` with normal
  certificate validation for the exact request host. The factory rejects
  proxies and hosts that are not in the profile. `TlsPinningProfile.target`
  selects the pin check:
  - `TlsPinTarget.leaf`: the factory hashes the leaf certificate SPKI with
    SHA-256 and compares it with the profile pins. On a mismatch, it destroys
    the socket before `HttpClient` writes the request.
  - `TlsPinTarget.issuer`: `SecureSocket.peerCertificate` exposes only the leaf
    certificate, so the factory validates with
    `SecurityContext(withTrustedRoots: false)` that contains only the profile's
    `issuerCertificates`. At startup, the SDK checks that the SPKI of each
    bundled certificate is pinned and that each pin has a certificate.
- On web, the transport reports an unsupported configuration. Assignment
  fetches fail before the SDK sends a request.

The SDK does not use `badCertificateCallback`. That callback runs only after
normal validation fails, so it cannot enforce pins on valid connections.

Under TLS pinning, `flagAssignmentsEndpoint` selects the assignment URL:

- `customFlagsEndpoint`, when set. Its host must be in the profile.
- Otherwise, `https://<profile host>/precompute-assignments` for a profile with
  one host. The site endpoint is not used. Because `customFlagsEndpoint` is
  null, the request keeps the automatic `X-DD-FEATURE-FLAGS-CAPABILITIES`
  header, like the site endpoint.
- A profile with more than one host and no `customFlagsEndpoint` is an invalid
  configuration.

A custom `httpClient` with TLS pinning is an invalid configuration. The SDK
logs a warning, keeps the custom client for telemetry, and fails assignment
fetches. Invalid profiles follow the same path.

Assignments fetched under a policy store a `responseProtectionPolicy`
identifier. The identifier is a SHA-256 digest of the method, mode, profile
name, hosts, pins, pin target, issuer certificates, and assignment endpoint. When a policy is configured, the
repository restores stored assignments only when their identifier matches.
Assignments fetched without protection have no identifier, so a required
policy does not restore them. Custom stores that rebuild `FlagsData` must keep
this field. Otherwise, stored assignments are not restored under a policy.

`TlsPinningProfile.datadogStagingV1` pins the Certainly issuers of
`protected.ff-cdn.datad0g.com`. Fastly manages the leaf certificates and their
keys, so the profile pins issuers. Fastly sends Certainly Intermediate R1 as
issued by Starfield Root G2. The profile does not trust Starfield Root G2.
Instead, it bundles Certainly Root R1 and the Certainly Intermediate R1 that
Root R1 issued for the same key, and the matching E1 certificates. Chain
building finds the trusted intermediate before the served one. The test PKI in
`test/tls_test_certificates.dart` reproduces this cross-sign.

`test/tls_pinning_io_test.dart` runs a local TLS server with test
certificates from `test/tls_test_certificates.dart`. Apple platforms reject TLS
server certificates that are valid for more than 825 days. The file describes
how to renew the leaf certificates without changing their SPKI pins.
