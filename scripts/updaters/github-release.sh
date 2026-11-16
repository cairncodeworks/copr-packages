#!/bin/sh
#
# Newest tag among the GitHub releases of OWNER/REPO.
#
#   github-release.sh OWNER/REPO [TAG_REGEX]
#
# Releases are checked newest first, so a repository that publishes rolling
# tags alongside real versions (Zen has "twilight-*") can be filtered with
# TAG_REGEX. Drafts are skipped; pre-releases are not, because for some
# projects every release is a beta.
#
set -eu

repo=${1:?usage: github-release.sh OWNER/REPO [TAG_REGEX]}
regex=${2:-}

if [ -n "${GH_TOKEN:-}" ]; then
    json=$(curl -fsSL \
        -H "Authorization: token $GH_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/$repo/releases?per_page=30")
else
    json=$(curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/$repo/releases?per_page=30")
fi

tags=$(printf '%s' "$json" | jq -r '.[] | select(.draft == false) | .tag_name')

if [ -n "$regex" ]; then
    tags=$(printf '%s\n' "$tags" | grep -E -- "$regex" || true)
fi

tag=$(printf '%s\n' "$tags" | head -n 1)

if [ -z "$tag" ]; then
    echo "github-release.sh: no matching tag in $repo" >&2
    exit 1
fi

printf '%s\n' "$tag"
