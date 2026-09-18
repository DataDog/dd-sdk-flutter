# Datadog Flags Example

This package contains command line examples for the Datadog Feature Flags SDK.

## Typed Evaluation

Provide the client token through the environment, then pass evaluation inputs as
arguments:

```bash
DD_CLIENT_TOKEN=<client-token> \
dart run datadog_flags_example:typed_evaluation \
  --env staging \
  --flag-key checkout.enabled \
  --flag-type boolean \
  --targeting-key test-subject
```

Optional:

- `DD_APPLICATION_ID` sets the Datadog application ID.
- `--site` selects the Datadog site. Defaults to `us1`.
- `--targeting-attributes` accepts a JSON object string.
