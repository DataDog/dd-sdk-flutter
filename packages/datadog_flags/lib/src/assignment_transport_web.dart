// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:http/http.dart' as http;

import 'flags_error.dart';
import 'response_protection.dart';

/// Browsers do not expose the TLS server certificate to applications, so
/// this platform cannot enforce [policy].
http.Client createTlsPinningClient(TlsPinningPolicy policy) {
  throw FlagsException.invalidConfiguration(
    'TLS pinning is not supported on web. Assignment requests are disabled '
    'while ResponseProtection.tlsPinning is required.',
  );
}
