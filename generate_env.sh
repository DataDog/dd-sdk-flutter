#!/usr/bin/env bash
#
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2016-Present Datadog, Inc.
#

########
# .env generation for package examples has moved to `melos.yaml` (`melos generate_env`).
# This script now only generates config for examples/native-hybrid-app.
########

set echo off

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

