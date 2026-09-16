# Changelog

## Unreleased

* Add opt-in assignment-request timeout and retry configuration, cancellable
  per-attempt requests, randomized exponential backoff, and bounded HTTP 503
  `Retry-After` support. The default makes one initial request without retries.
* Add an assignment-only HTTP client override and composable timeout and retry
  client helpers for applications that need lower-level transport control.

## 1.0.1

* Fix Flutter Web flag evaluation events failing with HTTP 403 errors caused by CORS preflight requests.
* Preserve evaluation metadata when sending flag evaluation events from Flutter Web.

## 1.0.0

* Initial preview release of the native Dart Datadog Feature Flags and Experimentation SDK.
* Support precomputed assignment fetching, typed local evaluation, exposure tracking, flag evaluation tracking, and optional assignment storage.
