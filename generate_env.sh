#!/usr/bin/env bash
#
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2016-Present Datadog, Inc.
#

########
# .env generation for package examples has moved to `melos.yaml` (`melos generate_env`).
# This script now only generates config for examples/native-hybrid-app and examples/simple_example
########

set echo off

pushd exmaples/simple_example
tee .env > /dev/null << END
# Edit this file with your Datadog client token, environment and application id
DD_CLIENT_TOKEN=$DD_CLIENT_TOKEN
DD_APPLICATION_ID=$DD_APPLICATION_ID
DD_ENV=prod

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
popd

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
