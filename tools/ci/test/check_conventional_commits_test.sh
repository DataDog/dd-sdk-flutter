#!/bin/sh

# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2026-Present Datadog, Inc.

set -eu

repo_root=$(pwd)
checker=$repo_root/tools/ci/check_conventional_commits.sh

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

test_repo=$(mktemp -d "${TMPDIR:-/tmp}/conventional-commits-test.XXXXXX")
trap 'rm -rf "$test_repo"' EXIT HUP INT TERM

git -C "$test_repo" init -q
git -C "$test_repo" config user.name 'CI Test'
git -C "$test_repo" config user.email 'ci-test@example.com'
git -C "$test_repo" config commit.gpgsign false
git -C "$test_repo" config core.hooksPath /dev/null
git -C "$test_repo" commit -q --allow-empty -m 'base commit'
base_revision=$(git -C "$test_repo" rev-parse HEAD)

git -C "$test_repo" commit -q --allow-empty -m 'add the implementation'
invalid_head=$(git -C "$test_repo" rev-parse HEAD)
if (cd "$test_repo" && sh "$checker" "$base_revision" "$invalid_head" >/dev/null 2>&1); then
  printf 'Expected a range without a Conventional Commit to fail.\n' >&2
  exit 1
fi

git -C "$test_repo" commit -q --allow-empty -m 'feat: summarize the implementation'
git -C "$test_repo" commit -q --allow-empty -m 'address review feedback'
review_head=$(git -C "$test_repo" rev-parse HEAD)
(cd "$test_repo" && sh "$checker" "$base_revision" "$review_head" >/dev/null)

printf 'Conventional Commit subject tests passed.\n'
