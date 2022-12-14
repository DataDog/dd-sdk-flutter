#!/usr/bin/env bash
#
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2016-Present Datadog, Inc.
#

declare -a dirs=(
    "packages/datadog_flutter_plugin"
    "packages/datadog_flutter_plugin/example"
    "packages/datadog_flutter_plugin/integration_test_app"
    "packages/datadog_flutter_plugin/e2e_test_app"
    "packages/datadog_tracking_http_client"
    "packages/datadog_tracking_http_client/example"
    "packages/datadog_grpc_interceptor"
)

for i in "${dirs[@]}"
do
    pushd "$i"
    flutter clean
    popd
done