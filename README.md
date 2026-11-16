# copr-packages

RPM spec files for the packages published in the
[CairnCodeWorks COPR repository](https://copr.fedorainfracloud.org/coprs/tuxcore/my-repo/).

One directory per package. Each directory holds the spec file that is actually
built, plus a small `pkg.toml` that says where upstream releases live. Nothing
is generated at release time: **the spec in git is the spec COPR builds.**

## Packages

| Package | Upstream | Kind |
| --- | --- | --- |
| `heroic-games-launcher` | [Heroic-Games-Launcher/HeroicGamesLauncher](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher) | repack of the upstream RPM |
| `protonup-qt` | [DavidoTek/ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt) | Python build from source |
| `zen-browser` | [zen-browser/desktop](https://github.com/zen-browser/desktop) | repack of the upstream tarball |

## Layout

```
.copr/Makefile                 SRPM generator used by COPR ("make srpm")
scripts/
  bump.sh                      detect new upstream releases, commit + tag
  set-version.sh               write a version into a spec, append %changelog
  srpm.sh                      download sources, run rpmbuild -bs
  validate.sh                  rpmspec / rpmlint / spectool checks
  rebuild-all.sh               trigger a COPR rebuild for every package
  new-package.sh               scaffold a new package directory
  updaters/                    one script per upstream release source
<package>/
  <package>.spec
  pkg.toml
```

## How it works

COPR is configured with the **SCM** source type and the **make srpm** SRPM
method. For every package, COPR clones this repository, sets the working
directory to the package's subdirectory and runs:

```
make -f <repo>/.copr/Makefile srpm outdir=<dir> spec=<package>.spec
```

`.copr/Makefile` installs `rpmdevtools`, then `scripts/srpm.sh` downloads every
`SourceN` URL with `spectool` and produces the SRPM with a plain
`rpmbuild -bs`. No COPR-specific spec templating is involved, so the specs stay
ordinary RPM specs that also build outside COPR.

Version bumps are automated by `.github/workflows/bump.yml`:

1. every 6 hours it runs `scripts/bump.sh`;
2. for each package the updater named in `pkg.toml` reports the newest upstream
   tag;
3. if that tag differs from the spec, the spec's version is rewritten, a
   `%changelog` entry is appended, and the change is committed;
4. a `PKGNAME-VERSION-RELEASE` tag is created;
5. the COPR GitHub webhook fires on tag creation and rebuilds **only that
   package**.

Nothing needs to be pasted into the COPR web UI when a release happens.

### Spec contract

`scripts/set-version.sh` rewrites exactly three lines, so every spec must keep
them:

```
%global upstream_tag <raw upstream tag, e.g. v2.22.4>
Version:        <rpm version>
Release:        <rpm release>%{?dist}
```

`SourceN` URLs must use `%{upstream_tag}`, not a reconstructed `v%{version}`,
so that upstream tag formats never have to be guessed.

### `pkg.toml`

Flat `key = "value"` pairs. Strings may use single or double quotes; single
quotes are preferred for regexes so backslashes stay literal.

| Key | Meaning |
| --- | --- |
| `updater` | `github-release`, `github-tag` or `pypi` (see `scripts/updaters/`) |
| `repo` | `owner/name` for the GitHub updaters |
| `project` | PyPI project name for the `pypi` updater |
| `tag_regex` | optional ERE; only matching tags are considered |
| `strip_prefix` | optional prefix removed from the tag to form `Version` (default `v`) |
| `prerelease_suffix` | `true` maps a trailing `b` to a pre-release `Release` |
| `include_prereleases` | `true` also accepts GitHub releases flagged as pre-release (by default they are skipped) |

## Adding a package

```sh
scripts/new-package.sh my-app github-release some-owner/some-repo
```

That creates `my-app/my-app.spec` and `my-app/pkg.toml`, and prints the COPR
command to run. Then:

1. fill in the spec — `heroic-games-launcher` is the reference for prebuilt
   Electron repacks, `zen-browser` for prebuilt tarballs, `protonup-qt` for
   Python source builds;
2. add the package to COPR (see below);
3. add it to the table at the top of this README.

New upstream source kinds need one new file in `scripts/updaters/`; nothing
else changes.

## Local build

Requires `fedora` (or a `fedora:latest` container) with `rpmdevtools`,
`rpmlint` and, for `protonup-qt`, `python3-devel pyproject-rpm-macros`.

```sh
cd zen-browser
spectool -g -C . zen-browser.spec
rpmbuild -bs --define "_sourcedir $PWD" --define "_srcrpmdir $PWD" zen-browser.spec
mock -r fedora-45-x86_64 --rebuild zen-browser-*.src.rpm
```

Or just validate the specs without building anything:

```sh
scripts/validate.sh
```

## COPR setup

One-time, per package:

```sh
copr-cli edit-package-scm tuxcore/my-repo \
    --name zen-browser \
    --clone-url https://github.com/cairncodeworks/copr-packages.git \
    --commit main \
    --subdir zen-browser \
    --spec zen-browser.spec \
    --method make_srpm \
    --webhook-rebuild on
```

If a flag name has changed, check `copr-cli edit-package-scm --help`; the
values (`make_srpm`, `on`) are what matter.

Then point the repository's GitHub webhook at the URL shown under
**Settings → Integrations** in the COPR project, with the event set to
**Branch or tag creation** only. Push events must stay off: a README change
would otherwise rebuild every package.

`rebuild-all.yml` (manual dispatch) triggers a rebuild of every package through
`copr-cli`; it needs a `COPR_CONFIG` repository secret containing the contents
of `~/.config/copr`.

## Notes and known limits

- **Prebuilt packages are x86_64 only.** COPR produces one SRPM per build and
  reuses it for every chroot, so an architecture-dependent `Source0` cannot
  work. aarch64 would need a second COPR package per application.
- **Only the current and previous Fedora release plus Rawhide are supported**
  (currently 44, 45 and Rawhide). `protonup-qt` needs `python3-pyside6`,
  `python3-vdf` and `python3-steam`, which older releases and other
  distributions do not ship, and COPR chroots are configured per project, not
  per package. Keep the list at the common denominator; a package that needs
  something else belongs in a COPR subproject such as `my-repo:custom:xyz`.
- **Scheduled workflows are disabled after 60 days without repository
  activity.** If `bump.yml` has not run, packages silently stop updating. Check
  the Actions tab after long breaks.
- **COPR email notifications should be on** (Fedora Notifications service), so
  a failed build does not go unnoticed.
- A build still fails when upstream changes an asset name or gains a
  dependency. No automation can avoid that; fix the spec and push.
