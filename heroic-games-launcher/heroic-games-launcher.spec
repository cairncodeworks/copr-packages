# Heroic is published as a prebuilt Electron bundle, and rebuilding it from
# source needs `pnpm install`, i.e. network access, which a build root does not
# have. This package therefore repackages upstream's own RPM: it already ships
# the correct /opt layout, the desktop entry, the hicolor icons and the
# `resources/package-type` marker ("rpm") that tells Heroic to leave updating to
# the package manager.
#
# Upstream's RPM is used rather than the tarball on purpose. The tarball
# contains no desktop file and no icons, so those would have to be rebuilt here
# from the Flatpak desktop entry plus a 1024x1024 PNG, and the layout would have
# to be guessed.

%global upstream_tag v2.22.4

# Repackaging prebuilt binaries: never generate debuginfo, and skip the brp-*
# post-install scripts. Those would try to strip the 219 MB bundled binary and
# rewrite shebangs under resources/app.asar.unpacked/, which carries third-party
# tooling (legendary, gogdl, nile, comet).
%global debug_package %{nil}
%global __os_install_post %{nil}

# zstd level 3 instead of the default 19: much faster on a 220 MB payload.
%global _binary_payload w3.zstdio

Name:           heroic-games-launcher
Version:        2.22.4
Release:        1%{?dist}
Summary:        Open source launcher for GOG, Epic Games and Amazon Games
License:        GPL-3.0-only
URL:            https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher

Source0:        %{url}/releases/download/%{upstream_tag}/Heroic-%{version}-linux-x86_64.rpm

# The prebuilt binaries are x86_64 only, and COPR produces a single SRPM per
# build and reuses it for every enabled chroot, so an architecture-dependent
# Source0 cannot work. aarch64 would need a separate COPR package.
ExclusiveArch:  x86_64

BuildRequires:  cpio
BuildRequires:  desktop-file-utils

# The payload bundles Chromium/Electron libraries whose sonames no distribution
# provides, so automatic dependency generation has to stay off. Upstream's own
# Requires list is mirrored below instead.
AutoReqProv:    no

Requires:       hicolor-icon-theme
Requires:       xdg-utils
Requires:       alsa-lib
Requires:       at-spi2-atk
Requires:       at-spi2-core
Requires:       cairo
Requires:       cups-libs
Requires:       expat
Requires:       fontconfig
Requires:       freetype
Requires:       glib2
Requires:       gtk3
Requires:       libX11
Requires:       libX11-xcb
Requires:       libXcomposite
Requires:       libXdamage
Requires:       libXext
Requires:       libXfixes
Requires:       libXrandr
Requires:       libXtst
Requires:       libdrm
Requires:       libnotify
Requires:       libsecret
Requires:       libuuid
Requires:       libxcb
Requires:       libxkbcommon
Requires:       libxkbcommon-x11
Requires:       mesa-libgbm
Requires:       nspr
Requires:       nss
Requires:       pango

Provides:       bundled(electron)

%description
Heroic is a free and open source launcher for GOG, Epic Games and Amazon
Games. It manages a separate Wine/Proton prefix per game, installs and updates
titles, tracks play time and integrates with the desktop.

This package repackages the official upstream Linux RPM.

%prep
rm -rf %{name}-%{version}
mkdir -p %{name}-%{version}
cd %{name}-%{version}
rpm2cpio %{SOURCE0} | cpio -idm --quiet --no-preserve-owner

%build
# Nothing to build: upstream ships binaries.

%install
cd %{name}-%{version}
cp -a opt usr %{buildroot}/

# Upstream installs no command line entry point; the desktop file calls
# /opt/Heroic/heroic directly. Add a symlink so `heroic` works in a terminal.
mkdir -p %{buildroot}%{_bindir}
ln -s /opt/Heroic/heroic %{buildroot}%{_bindir}/heroic

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/heroic.desktop

%files
# Upstream's licence files (LICENSE.electron.txt, LICENSES.chromium.html) are
# part of the payload and stay where the application expects them.
%dir /opt/Heroic
/opt/Heroic/*
%{_bindir}/heroic
%{_datadir}/applications/heroic.desktop
%{_datadir}/icons/hicolor/*/apps/heroic.png

%changelog
* Mon Nov 16 2026 CairnCodeWorks <noreply@cairncodeworks.dev> - 2.22.4-1
- Initial package
