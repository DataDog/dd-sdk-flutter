// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

/// HTTP method of the resource
enum RumHttpMethod { post, get, head, put, delete, patch }

/// Describe the type of a RUM Action.
enum RumActionType { click, tap, scroll, swipe, custom }

/// Describe the source of a RUM Error.
enum RumErrorSource {
  /// Error originated in the source code.
  source,

  /// Error originated in the network layer.
  network,

  /// Error originated in a webview.
  webview,

  /// Error originated in a web console (used by bridges).
  console,

  /// Custom error source.
  custom,
}

/// Describe the type of resource loaded.
enum RumResourceType {
  document,
  image,
  xhr,
  beacon,
  css,
  fetch,
  font,
  js,
  media,
  other,
  native,
}

/// Represents the possible reasons for a failed operation.
enum RumOperationFailureReason {
  /// Represents a failure caused by an error during execution.
  error,

  /// Represents a failure caused by user or process abandonment.
  abandoned,

  /// Represents a failure due to other unspecified reasons.
  other,
}
