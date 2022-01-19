#!/usr/bin/env bash
# This file contains a set of "preflight" checks that you can run before pushing
# up a branch or creating a pull request, to make sure you're following all the
# standards put in place in the repo.

set -e

# Fix Android linter issues
pushd example/android
./gradlew ktlintFormat
./gradlew detekt
popd

# Fix iOS linter issues
swiftlint --fix

# Run flutter analyze
flutter analyze

# Run iOS / Android integration tests
bitrise run setup
bitrise run integration_ios
bitrise run integration_android
