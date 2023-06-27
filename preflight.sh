#!/usr/bin/env bash
#
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2016-Present Datadog, Inc.
#

# This file contains a set of "preflight" checks that you can run before pushing
# up a branch or creating a pull request, to make sure you're following all the
# standards put in place in the repo.

set -e

# These are directories that contain native code that needs to be linted
pluginDirs=(
  "packages/datadog_flutter_plugin"
  "packages/datadog_webview_tracking"
)

# Fix Android linter issues
for f in ${pluginDirs[@]}; do
  pushd $f
  pushd example/android
  ./gradlew ktlintFormat
  ./gradlew detekt
  popd

  # Fix iOS linter issues
  swiftlint --fix
  popd
done


# Run iOS / Android integration tests
bitrise run core_build
