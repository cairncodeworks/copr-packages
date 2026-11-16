#!/bin/sh
#
# Static checks for every package in the repository. Runs in CI on push and
# pull request, and locally from the repository root.
#
# Nothing here needs network access: rpmspec expands macros, spectool only
# lists the sources it would download.
#
set -eu

cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

status=0

for meta in */pkg.toml; do
    pkg=$(dirname "$meta")
    spec="$pkg/$pkg.spec"

    if [ ! -f "$spec" ]; then
        echo "::error::$pkg: pkg.toml exists but $spec does not"
        status=1
        continue
    fi

    # Contract required by scripts/set-version.sh.
    for field in 'upstream_tag' 'Version:' 'Release:'; do
        case "$field" in
            upstream_tag) pattern='^%global upstream_tag ' ;;
            *)            pattern="^$field " ;;
        esac
        if ! grep -q "$pattern" "$spec"; then
            echo "::error::$pkg: $spec has no '$pattern' line"
            status=1
        fi
    done

    if ! rpmspec -P "$spec" >/dev/null; then
        echo "::error::$pkg: rpmspec could not parse $spec"
        status=1
    fi

    if ! spectool -l "$spec" >/dev/null; then
        echo "::error::$pkg: a Source URL in $spec cannot be resolved"
        status=1
    fi

    # rpmlint findings are reported but do not fail the build: the specs
    # intentionally deviate from the Fedora guidelines (prebuilt payloads).
    rpmlint -i "$spec" || echo "::warning::$pkg: rpmlint reported issues"
done

exit "$status"
