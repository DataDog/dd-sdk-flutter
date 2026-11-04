# Migrate to OpenFeature

| Deprecated API | OpenFeature replacement |
| --- | --- |
| `DatadogFlags.enable` and `sharedClient` | `setProviderAndWait` and `getClient` |
| `DatadogFlagsClient.initialize` | `setEvaluationContextAndWait` |
| `FlagsEvaluationContext` for evaluation | `EvaluationContext` |
| `FlagDetails` | `FlagEvaluationDetails` |
| `FlagEvaluationError` | `ErrorCode` |
| `getObjectDetails` | `getStructureDetails` for JSON objects |
| `DatadogFlags.disable` | `OpenFeatureAPI.shutdown` |

Configuration and store interfaces remain available. Legacy clients remain
functional during migration. After a legacy client's `shutdown()`, obtain a new
client with `sharedClient()`; the old client cannot be initialized again.

For Flutter RUM, add `DatadogRumHook` from `datadog_flags_flutter` to the
OpenFeature client. Do not initialize the deprecated plugin for the same flags.
Each Dart isolate must create its own OpenFeature API and provider state.

