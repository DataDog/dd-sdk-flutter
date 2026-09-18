#!/usr/bin/env bash
#
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2016-Present Datadog, Inc.
#

########
# This script is being moved to `melos.yaml`. Use `melos generate_env` instead.
########

set echo off

dotEnvFiles=(
  "packages/datadog_flutter_plugin/example/.env"
  "packages/datadog_flutter_plugin/integration_test_app/.env"
  "packages/datadog_tracking_http_client/example/.env"
  "packages/datadog_webview_tracking/example/.env"
  "examples/simple_example/.env"
  "test_apps/stress_test/.env"
)

for f in ${dotEnvFiles[@]}; do
  echo "Generating $f"
  tee $f > /dev/null << END
# Edit this file with your Datadog client token, environment and application id
DD_CLIENT_TOKEN=$DD_CLIENT_TOKEN
DD_APPLICATION_ID=$DD_APPLICATION_ID
DD_ENV=prod
END
done

flagsTargetingAttributesJson=${FLAGS_TARGETING_ATTRIBUTES_JSON:-'{"attr1":"value1","companyId":"1"}'}
flagDotEnvFiles=(
  "examples/simple_example/.env"
)

for f in ${flagDotEnvFiles[@]}; do
  tee -a $f > /dev/null << END

# Optional Datadog Flags example settings.
DD_SITE=${DD_SITE:-us1}
FLAGS_TARGETING_KEY=${FLAGS_TARGETING_KEY:-test_subject4}
FLAGS_TARGETING_ATTRIBUTES_JSON=$flagsTargetingAttributesJson
FLAGS_BOOLEAN_KEYS=${FLAGS_BOOLEAN_KEYS:-checkout.enabled}
FLAGS_STRING_KEYS=${FLAGS_STRING_KEYS:-checkout.copy}
FLAGS_INTEGER_KEYS=${FLAGS_INTEGER_KEYS:-checkout.limit}
FLAGS_DOUBLE_KEYS=${FLAGS_DOUBLE_KEYS:-checkout.ratio}
FLAGS_OBJECT_KEYS=${FLAGS_OBJECT_KEYS:-checkout.config}
END
done

e2eDotEnvFiles=(
  "packages/datadog_flutter_plugin/e2e_test_app/.env"
)

for f in ${e2eDotEnvFiles[@]}; do
  tee $f > /dev/null << END
DD_CLIENT_TOKEN=$DD_E2E_CLIENT_TOKEN
DD_APPLICATION_ID=$DD_E2E_APPLICATION_ID
DD_E2E_IS_ON_CI=${IS_ON_CI:-false}
END
done 

pushd examples/native-hybrid-app/android/app/src/main/res/
mkdir raw
tee ./raw/dd_config.json > /dev/null << END
{
  "client_token": "$DD_CLIENT_TOKEN",
  "application_id": "$DD_APPLICATION_ID"
}
END
popd

pushd examples/native-hybrid-app/ios/iOS\ Flutter\ Hybrid\ Example
tee ./ddog_config.plist > /dev/null << END
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>client_token</key>
	<string>$DD_CLIENT_TOKEN</string>
	<key>application_id</key>
	<string>$DD_APPLICATION_ID</string>
</dict>
</plist>
END
popd
