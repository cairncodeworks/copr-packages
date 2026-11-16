#!/bin/sh
#
# Produce an SRPM from the spec in the current directory.
#
# Called by .copr/Makefile inside the COPR build chroot. Also usable locally
# from a package directory:
#
#   ../../scripts/srpm.sh --spec zen-browser.spec --outdir .
#
set -eu

spec=
outdir=

while [ $# -gt 0 ]; do
    case "$1" in
        --spec)   spec=$2;   shift 2 ;;
        --outdir) outdir=$2; shift 2 ;;
        *) echo "srpm.sh: unknown option: $1" >&2; exit 2 ;;
    esac
done

if [ -z "$spec" ] || [ -z "$outdir" ]; then
    echo "usage: srpm.sh --spec SPEC --outdir DIR" >&2
    exit 2
fi

[ -f "$spec" ] || { echo "srpm.sh: no such spec: $spec" >&2; exit 1; }

mkdir -p "$outdir"

# Download every SourceN URL next to the spec. rpmbuild does not fetch
# anything itself, it only looks for the files by basename.
spectool -g -C . "$spec"

rpmbuild -bs \
    --define "_sourcedir $PWD" \
    --define "_srcrpmdir $outdir" \
    --define "_topdir $PWD" \
    "$spec"
