# Migrate to OpenFeature

| Deprecated API | OpenFeature replacement |
| --- | --- |
| `DatadogFlags.enable` and `sharedClient` | `setProviderAndWait` and `getClient` |
| `DatadogFlagsClient.initialize` | `setEvaluationContextAndWait` |
| `FlagDetails` | `FlagEvaluationDetails` |
| `FlagEvaluationError` | `ErrorCode` |
| `getObjectDetails` | `getStructureDetails` for JSON objects |
| `DatadogFlags.disable` | `OpenFeatureAPI.shutdown` |
| `DatadogFlags.reset` and `DatadogFlagsClient.reset` | Call `delete` on your store with the domain name, or `default`. Shutdown clears in-memory assignments. |

Configuration and store interfaces remain available. Legacy clients remain
functional during migration. After a legacy client's `shutdown()`, obtain a new
client with `sharedClient()`; the old client cannot be initialized again.

For Flutter RUM, add `DatadogRumHook` from `datadog_flags_flutter` to the
API with `OpenFeatureAPI.instance.addHooks`. Register the hook again after shutdown. Do not initialize the deprecated plugin for the same flags.
Each Dart isolate must create its own OpenFeature API and provider state.


`FlagsEvaluationContext` remains supported by the storage interface. Application
evaluations use OpenFeature `EvaluationContext`.

Use `DatadogProvider.fromConfiguration(configuration)` with a
`DatadogFlagsConfiguration`.
The provider requires a positive initialization timeout of at most 20 seconds.
It applies the budget to initialization, each context change, and each refresh.
