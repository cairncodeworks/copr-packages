#!/bin/sh
#
# Trigger a rebuild of every package through copr-cli.
#
#   COPR_PROJECT=tuxcore/my-repo scripts/rebuild-all.sh
#
# Needs ~/.config/copr, or COPR_CONFIG containing the same ini text.
# This is the escape hatch for changes that do not create a new tag, such as
# edits to .copr/Makefile or to a spec's dependencies: those do not fire the
# COPR webhook.
#
set -eu

project=${COPR_PROJECT:?set COPR_PROJECT to OWNER/PROJECT, e.g. tuxcore/my-repo}

if [ -n "${COPR_CONFIG:-}" ]; then
    mkdir -p "$HOME/.config"
    printf '%s\n' "$COPR_CONFIG" > "$HOME/.config/copr"
    chmod 600 "$HOME/.config/copr"
fi

cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

for meta in */pkg.toml; do
    pkg=$(dirname "$meta")
    echo ":: triggering $project/$pkg"
    copr-cli build-package "$project" --name "$pkg"
done
