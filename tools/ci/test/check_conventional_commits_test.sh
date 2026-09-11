#!/bin/sh

# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2026-Present Datadog, Inc.

set -eu

checker=tools/ci/check_conventional_commits.sh

for subject in \
  'feat: add a feature' \
  'fix(web): avoid a crash' \
  'feat(flags)!: change the API' \
  'build-tool: update the image'
do
  sh "$checker" --subject "$subject" >/dev/null
done

for subject in \
  '[FFL-3028] Add a provider' \
  'Add a provider' \
  'FEAT: add a provider' \
  'feat:add a provider' \
  'feat(): add a provider' \
  'feat: '
do
  if sh "$checker" --subject "$subject" >/dev/null 2>&1; then
    printf 'Expected an invalid subject: %s\n' "$subject" >&2
    exit 1
  fi
done

printf 'Conventional Commit subject tests passed.\n'
