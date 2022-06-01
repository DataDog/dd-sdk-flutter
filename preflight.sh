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

# Fix Android linter issues
pushd packages/datadog_flutter_plugin/example/android
./gradlew ktlintFormat
./gradlew detekt
popd

# Fix iOS linter issues
pushd packages/datadog_flutter_plugin
swiftlint --fix
popd

# Run iOS / Android integration tests
bitrise run push_to_develop_or_master
