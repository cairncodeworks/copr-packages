#!/bin/sh
#
# Newest version of a PyPI project.
#
#   pypi.sh PROJECT
#
set -eu

project=${1:?usage: pypi.sh PROJECT}

version=$(curl -fsSL "https://pypi.org/pypi/$project/json" | jq -r '.info.version')

if [ -z "$version" ] || [ "$version" = "null" ]; then
    echo "pypi.sh: could not read the version of $project" >&2
    exit 1
fi

printf '%s\n' "$version"
