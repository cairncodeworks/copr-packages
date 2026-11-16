#!/bin/sh
#
# Write a version into a package spec and record it in %changelog.
#
#   set-version.sh <package-dir> <upstream-tag> <version> <release>
#
# The spec must contain these three lines, which is the contract every package
# in this repository follows:
#
#   %global upstream_tag <tag>
#   Version:        <version>
#   Release:        <release>%{?dist}
#
set -eu

if [ $# -ne 4 ]; then
    echo "usage: set-version.sh PACKAGE-DIR UPSTREAM-TAG VERSION RELEASE" >&2
    exit 2
fi

pkg=$1
tag=$2
version=$3
release=$4

spec="$pkg/$pkg.spec"
[ -f "$spec" ] || { echo "set-version.sh: no such spec: $spec" >&2; exit 1; }

for pattern in '^%global upstream_tag ' '^Version: ' '^Release: '; do
    if ! grep -q "$pattern" "$spec"; then
        echo "set-version.sh: $spec has no '$pattern' line" >&2
        exit 1
    fi
done

sed -i \
    -e "s|^%global upstream_tag .*|%global upstream_tag $tag|" \
    -e "s|^Version: .*|Version:        $version|" \
    -e "s|^Release: .*|Release:        $release%{?dist}|" \
    "$spec"

date=$(LC_ALL=C date '+%a %b %d %Y')

cat >> "$spec" <<EOF

* $date CairnCodeWorks <noreply@cairncodeworks.dev> - $version-$release
- Update to $tag
EOF
