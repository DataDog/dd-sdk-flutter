#!/usr/bin/env bash
#
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2016-Present Datadog, Inc.
#
# Prepares the repo for development.

set -e
flutter precache --ios --android --web
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
    "packages/datadog_webview_tracking"
    "tools/e2e_generator"
    "tools/releaser"
    "tools/third_party_scanner"

    "examples/native-hybrid-app/flutter_module"
)

for i in "${all_dirs[@]}"
do
    pushd "$i"
    flutter pub get
    # Check and update pods
    if [ -d "example/ios" ]
    then
        pushd "example/ios"
        pod update
        popd
    fi
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