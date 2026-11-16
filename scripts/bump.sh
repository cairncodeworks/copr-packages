#!/bin/sh
#
# Bump every package whose upstream published something newer than what the
# spec currently says.
#
# Run from anywhere inside the repository:
#
#   scripts/bump.sh              bump everything, commit and tag
#   scripts/bump.sh --dry-run    report only
#   scripts/bump.sh zen-browser  bump a single package
#
# Pushing is left to the caller (.github/workflows/bump.yml), so a local run
# never publishes anything by accident.
#
set -eu

dry_run=0
only=

for arg in "$@"; do
    case "$arg" in
        --dry-run) dry_run=1 ;;
        -*) echo "bump.sh: unknown option: $arg" >&2; exit 2 ;;
        *)  only=$arg ;;
    esac
done

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

# Read a flat `key = "value"` (or `key = 'value'`) pair from a pkg.toml.
toml_get() {
    value=$(sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*//p" "$1" | head -n 1)
    # Strip one layer of matching quotes. Done character-wise, because a
    # backslash inside ${...} is not portable (dash and bash disagree on it).
    case "$(printf '%.1s' "$value")" in
        "'" | '"')
            value=${value#?}
            value=${value%?}
            ;;
    esac
    printf '%s\n' "$value"
}

spec_version() {
    sed -n 's/^Version:[[:space:]]*//p' "$1" | head -n 1
}

# Release as written in the spec, with the %{?dist} suffix removed.
spec_release() {
    release_line=$(sed -n 's/^Release:[[:space:]]*//p' "$1" | head -n 1)
    printf '%s\n' "${release_line%%%*}"
}

changed=0

for meta in */pkg.toml; do
    pkg=$(dirname "$meta")

    if [ -n "$only" ] && [ "$only" != "$pkg" ]; then
        continue
    fi

    spec="$pkg/$pkg.spec"
    updater=$(toml_get "$meta" updater)

    if [ -z "$updater" ]; then
        echo "bump.sh: $meta has no 'updater' key" >&2
        exit 1
    fi

    case "$updater" in
        github-release|github-tag)
            upstream_repo=$(toml_get "$meta" repo)
            [ -n "$upstream_repo" ] || { echo "bump.sh: $meta has no 'repo' key" >&2; exit 1; }
            tag=$("$repo_root/scripts/updaters/$updater.sh" "$upstream_repo" "$(toml_get "$meta" tag_regex)")
            ;;
        pypi)
            project=$(toml_get "$meta" project)
            [ -n "$project" ] || { echo "bump.sh: $meta has no 'project' key" >&2; exit 1; }
            tag=$("$repo_root/scripts/updaters/pypi.sh" "$project")
            ;;
        *)
            echo "bump.sh: unknown updater '$updater' in $meta" >&2
            exit 1
            ;;
    esac

    strip=$(toml_get "$meta" strip_prefix)
    [ -n "$strip" ] || strip=v

    version=${tag#"$strip"}
    release=1

    # Upstream tags a beta as "1.24.2b". Mapping it to Version 1.24.2 with
    # Release 0.1.beta keeps `dnf upgrade` working when 1.24.2 final appears,
    # which a plain Version of "1.24.2b" would break.
    if [ "$(toml_get "$meta" prerelease_suffix)" = "true" ]; then
        case "$version" in
            *b) version=${version%b}; release=0.1.beta ;;
        esac
    fi

    current=$(spec_version "$spec")
    current_release=$(spec_release "$spec")

    # Both fields are compared: upstream moving from "1.24.2b" to "1.24.2"
    # keeps Version at 1.24.2 and only changes Release from 0.1.beta to 1, and
    # that still has to be released.
    if [ "$version" = "$current" ] && [ "$release" = "$current_release" ]; then
        echo "$pkg: up to date ($current-$current_release)"
        continue
    fi

    echo "$pkg: $current-$current_release -> $version-$release (upstream tag $tag)"

    if [ "$dry_run" -eq 1 ]; then
        changed=1
        continue
    fi

    sh "$repo_root/scripts/set-version.sh" "$pkg" "$tag" "$version" "$release"

    git add -- "$pkg/$pkg.spec"
    git commit -q -m "$pkg: update to $version"

    # Annotated so that `git push --follow-tags` picks it up. COPR reads the
    # package name out of the tag, hence the PKGNAME-VERSION-RELEASE form.
    tag_name="$pkg-$version-$release"
    if git rev-parse -q --verify "refs/tags/$tag_name" >/dev/null; then
        echo "$pkg: tag $tag_name already exists, not moving it"
    else
        git tag -a "$tag_name" -m "$pkg $version-$release"
    fi

    changed=1
done

if [ "$changed" -eq 0 ]; then
    echo "nothing to do"
fi
