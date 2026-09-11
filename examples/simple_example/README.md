# Datadog Flutter Plugin -  Simple Example

This is a more realistic example of how you use the Datadog Flutter Plugin in a real-world scenario.  This includes:
    
    * Using GoRouter with the DatadogNavigationObserver
    * Automatic network tracing with `datadog_tracking_http_client`
    * User interaction tracking with RumUserActionDetector
    * Error/Crash handling with manually reported errors
    * OpenFeature initialization and typed evaluation with the Datadog provider

## Setup

Generate the local `.env` file before running this example:

```bash
../../generate_env.sh
flutter run
```

Runtime credentials and optional flag overrides come from `.env`, which is
ignored by git. Do not commit real client tokens, application IDs, customer
names, org names, or customer-owned flag keys.

## Feature Flags

The `Flags` screen uses `openfeature_dart_client_sdk` with
`datadog_openfeature_provider`. This is the recommended integration for new
Dart and Flutter applications. The app sets an OpenFeature evaluation context,
registers the Datadog provider, and evaluates typed flags with programmatic
defaults.

The Datadog Flutter SDK initializes separately for RUM, Logs, and Traces. The
OpenFeature provider owns the Flags runtime and its assignment lifecycle.

To test feature flags in your own organization, customize the generated `.env`
file:

```dotenv
DD_SITE=us1
FLAGS_TARGETING_KEY=user-123
FLAGS_TARGETING_ATTRIBUTES_JSON={"companyId":"company-456"}
FLAGS_BOOLEAN_KEYS=checkout.enabled
FLAGS_STRING_KEYS=checkout.copy
FLAGS_INTEGER_KEYS=checkout.limit
FLAGS_DOUBLE_KEYS=checkout.ratio
FLAGS_OBJECT_KEYS=checkout.config
```
