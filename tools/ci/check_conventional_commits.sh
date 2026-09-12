#!/bin/sh

# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2026-Present Datadog, Inc.

set -eu

pattern='^[a-z][a-z0-9-]*(\([^()]+\))?!?: [^[:space:]].*$'

write_expected_format() {
  printf '\nExpected: <type>[optional scope][!]: <description>\n' >&2
  printf 'Example: feat(flags): add initialization timeout\n' >&2
}

check_subject() {
  printf '%s\n' "$1" | LC_ALL=C grep -Eq "$pattern"
}

if [ "$#" -eq 2 ] && [ "$1" = "--subject" ]; then
  if check_subject "$2"; then
    printf 'The commit subject uses the Conventional Commit format.\n'
    exit 0
  fi

  printf 'Invalid commit subject: %s\n' "$2" >&2
  write_expected_format
  exit 1
fi

if [ "$#" -ne 2 ]; then
  printf 'Usage: sh tools/ci/check_conventional_commits.sh <base revision> <head revision>\n' >&2
  printf '   or: sh tools/ci/check_conventional_commits.sh --subject <commit subject>\n' >&2
  exit 2
fi

base_revision=$1
head_revision=$2
if [ -z "$base_revision" ] || printf '%s\n' "$base_revision" | grep -Eq '^0+$'; then
  printf 'The base revision is not available.\n' >&2
  exit 2
fi

log_file=$(mktemp "${TMPDIR:-/tmp}/conventional-commits.XXXXXX")
trap 'rm -f "$log_file"' EXIT HUP INT TERM

if ! git log --no-merges --format='%H%x09%s' "$base_revision..$head_revision" > "$log_file"; then
  exit 2
fi

invalid=0
tab=$(printf '\t')
while IFS="$tab" read -r sha subject; do
  [ -n "$sha" ] || continue
  if ! check_subject "$subject"; then
    if [ "$invalid" -eq 0 ]; then
      printf 'These commits do not use Conventional Commit subjects:\n' >&2
    fi
    printf '  %.8s %s\n' "$sha" "$subject" >&2
    invalid=1
  fi
done < "$log_file"

if [ "$invalid" -ne 0 ]; then
  write_expected_format
  exit 1
fi

printf 'All non-merge commits use Conventional Commit subjects.\n'
