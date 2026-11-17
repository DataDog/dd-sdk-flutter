#!/usr/bin/env bash
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2019-Present Datadog, Inc.

# Fails unless the commit is reachable from a release branch: `main`,
# `v4-main`, or a support branch (`release/<package>/v<major>[.<minor>].x`).
# Mirrors publish_release.dart's branch rules; keep them in sync.
#
# Usage: verify_tag_provenance.sh <commit-sha> [remote]
# Needs the remote's branches fetched as refs/remotes/<remote>/*.
set -euo pipefail

sha="${1:?usage: verify_tag_provenance.sh <commit-sha> [remote]}"
remote="${2:-origin}"
approved='^(main|v4-main|release/[^/]+/v[0-9]+(\.[0-9]+)?\.x)$'

if ! git cat-file -e "${sha}^{commit}" 2>/dev/null; then
  echo "::error::$sha is not a commit in this checkout." >&2
  exit 1
fi

while IFS= read -r ref; do
  branch="${ref#refs/remotes/${remote}/}"
  [[ "$branch" =~ $approved ]] || continue
  if git merge-base --is-ancestor "$sha" "$ref"; then
    echo "$sha is reachable from $remote/$branch."
    exit 0
  fi
done < <(git for-each-ref --format='%(refname)' "refs/remotes/${remote}/")

echo "::error::$sha is not reachable from any approved release branch (main, v4-main, release/<package>/v<major>[.<minor>].x); refusing to publish." >&2
exit 1
