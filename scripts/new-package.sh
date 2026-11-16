#!/bin/sh
#
# Scaffold a new package directory.
#
#   new-package.sh <name> <updater> <upstream>
#
#   new-package.sh my-app github-release some-owner/some-repo
#   new-package.sh some-tool pypi some-tool
#
# The generated spec is a skeleton that parses but does not build yet; fill in
# Summary, License, SourceN and %files. Use the existing packages as reference:
#
#   heroic-games-launcher  prebuilt Electron RPM repack
#   zen-browser            prebuilt tarball repack
#   protonup-qt            Python source build
#
set -eu

if [ $# -ne 3 ]; then
    echo "usage: new-package.sh NAME UPDATER UPSTREAM" >&2
    echo "  UPDATER: github-release | github-tag | pypi" >&2
    exit 2
fi

name=$1
updater=$2
upstream=$3

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

case "$updater" in
    github-release|github-tag) upstream_key=repo ;;
    pypi)                      upstream_key=project ;;
    *) echo "new-package.sh: unknown updater: $updater" >&2; exit 2 ;;
esac

if [ -e "$name" ]; then
    echo "new-package.sh: $name already exists" >&2
    exit 1
fi

mkdir -p "$name"

cat > "$name/pkg.toml" <<EOF
updater = "$updater"
$upstream_key = "$upstream"
EOF

case "$updater" in
    github-release|github-tag) url="https://github.com/$upstream" ;;
    *)                         url="https://pypi.org/project/$upstream/" ;;
esac

cat > "$name/$name.spec" <<EOF
# TODO: explain here why the package is built the way it is.

%global upstream_tag v0.0.0

Name:           $name
Version:        0.0.0
Release:        1%{?dist}
Summary:        TODO

License:        TODO
URL:            $url

Source0:        %{url}/archive/refs/tags/%{upstream_tag}.tar.gz

%description
TODO

%prep
%autosetup -n %{name}-%{version}

%build

%install
# TODO

%files
# TODO

%changelog
EOF

echo "created $name/pkg.toml and $name/$name.spec"
echo
echo "next:"
echo "  1. fill in the spec"
echo "  2. scripts/validate.sh"
echo "  3. copr-cli edit-package-scm <OWNER>/<PROJECT> \\"
echo "         --name $name \\"
echo "         --clone-url https://github.com/cairncodeworks/copr-packages.git \\"
echo "         --commit main \\"
echo "         --subdir $name \\"
echo "         --spec $name.spec \\"
echo "         --method make_srpm \\"
echo "         --webhook-rebuild on"
