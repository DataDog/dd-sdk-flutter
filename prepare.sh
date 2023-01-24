#!/usr/bin/env bash
#
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2016-Present Datadog, Inc.
#
# Prepares the repo for development.

set -e
./generate_env.sh

declare -a all_dirs=(
    "packages/datadog_common_test"
    "packages/datadog_flutter_plugin"
    "packages/datadog_flutter_plugin/example"
    "packages/datadog_flutter_plugin/integration_test_app"
    "packages/datadog_flutter_plugin/e2e_test_app"
    "packages/datadog_tracking_http_client"
    "packages/datadog_tracking_http_client/example"
    "packages/datadog_grpc_interceptor"
    "tools/e2e_generator"
    "tools/releaser"
    "tools/third_party_scanner"
)

for i in "${all_dirs[@]}"
do
    pushd "$i"
    flutter pub get
    popd
done

declare -a need_generation=(
    "packages/datadog_common_test"
    "packages/datadog_flutter_plugin"
)

for i in "${need_generation[@]}"
do
    pushd "$i"
    flutter pub run build_runner build
    popd
done