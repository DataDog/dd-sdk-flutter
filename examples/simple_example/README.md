# Datadog Flutter Plugin -  Simple Example

This is a more realistic example of how you use the Datadog Flutter Plugin in a real-world scenario.  This includes:
    
    * Using GoRouter with the DatadogNavigationObserver
    * Automatic network tracing with `datadog_tracking_http_client`
    * User interaction tracking with RumUserActionDetector
    * Error/Crash handling with manually reported errors
    * Basic feature flag initialization and typed evaluation with `datadog_flags`

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

The `Flags` screen initializes `DatadogFlags`, refreshes assignments for one
evaluation context, and evaluates boolean, string, integer, double, and JSON
flags with programmatic defaults.

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
