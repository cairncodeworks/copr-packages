#!/bin/sh
#
# Newest tag of OWNER/REPO, for projects that tag without publishing a GitHub
# release.
#
#   github-tag.sh OWNER/REPO [TAG_REGEX]
#
# The tags API returns tags in reverse chronological creation order.
#
set -eu

repo=${1:?usage: github-tag.sh OWNER/REPO [TAG_REGEX]}
regex=${2:-}

if [ -n "${GH_TOKEN:-}" ]; then
    json=$(curl -fsSL \
        -H "Authorization: token $GH_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/$repo/tags?per_page=100")
else
    json=$(curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/$repo/tags?per_page=100")
fi

tags=$(printf '%s' "$json" | jq -r '.[].name')

if [ -n "$regex" ]; then
    tags=$(printf '%s\n' "$tags" | grep -E -- "$regex" || true)
fi

tag=$(printf '%s\n' "$tags" | head -n 1)

if [ -z "$tag" ]; then
    echo "github-tag.sh: no matching tag in $repo" >&2
    exit 1
fi

printf '%s\n' "$tag"
