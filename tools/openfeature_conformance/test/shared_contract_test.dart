// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:openfeature_client_provider_contract/client_provider_contract.dart';

import 'support/datadog_provider_fixture.dart';

void main() => runClientProviderContract(
  providerName: 'Datadog',
  createFixture: DatadogProviderFixture.new,
);
