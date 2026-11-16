# Zen is a Firefox fork published as a prebuilt tarball. Building Gecko from
# source takes hours and needs a very specific toolchain, so this package
# repackages the official Linux build.
#
# Upstream only tags betas ("1.24.2b"). Using the tag verbatim as Version would
# break `dnf upgrade` the day 1.24.2 final appears: rpmvercmp sorts "1.24.2b"
# *above* "1.24.2", so the final release would never replace the beta. The
# trailing letter is therefore mapped to a pre-release Release instead, which
# sorts below 1.
%global upstream_tag 1.24.2b

%global debug_package %{nil}
%global __os_install_post %{nil}

%global _binary_payload w3.zstdio

# Do not scan the bundled Gecko libraries for dependencies or provides; the
# system libraries that are actually needed are listed explicitly below.
%global __requires_exclude_from ^%{_libdir}/zen/
%global __provides_exclude_from ^%{_libdir}/zen/

Name:           zen-browser
Version:        1.24.2
Release:        0.1.beta%{?dist}
Summary:        Firefox-based browser with a calm, distraction-free interface
License:        MPL-2.0
URL:            https://github.com/zen-browser/desktop

Source0:        %{url}/releases/download/%{upstream_tag}/zen.linux-x86_64.tar.xz
# Upstream's AppImage desktop entry and update policy, taken from the same tag.
Source1:        %{url}/raw/%{upstream_tag}/build/AppDir/zen.desktop
Source2:        %{url}/raw/%{upstream_tag}/build/AppDir/distribution/policies.json
Source3:        %{url}/raw/%{upstream_tag}/LICENSE

# One SRPM is built per COPR build and reused for every chroot, so the source
# cannot depend on the target architecture. aarch64 would need its own package.
ExclusiveArch:  x86_64

BuildRequires:  desktop-file-utils

Requires:       hicolor-icon-theme

# Gecko opens most of these with dlopen(), so the automatic ELF dependency
# generator cannot see them, and it is disabled for the payload anyway.
Requires:       alsa-lib
Requires:       cairo
Requires:       dbus-libs
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
Requires:       libXt
Requires:       libdrm
Requires:       libva
Requires:       libwayland-client
Requires:       libwayland-egl
Requires:       libxcb
Requires:       libxkbcommon
Requires:       mesa-libEGL
Requires:       mesa-libGL
Requires:       mesa-libgbm
Requires:       nspr
Requires:       nss
Requires:       pango
Requires:       pipewire-libs
Requires:       pulseaudio-libs

Provides:       bundled(gecko)

%description
Zen is a browser built on the Firefox engine that aims to be calmer and less
distracting than a traditional browser: vertical tabs, a single compact
toolbar, split view and workspaces.

This package repackages the official upstream Linux build.

%prep
%autosetup -n zen

%build
# Nothing to build: upstream ships binaries.

%install
install -d %{buildroot}%{_libdir}/zen
cp -a . %{buildroot}%{_libdir}/zen/

# Updates must come from the package manager, never from the built-in updater:
# it would try to overwrite files owned by RPM.
install -d %{buildroot}%{_libdir}/zen/distribution
install -m 0644 %{SOURCE2} %{buildroot}%{_libdir}/zen/distribution/policies.json

# Same environment upstream's AppImage sets, see build/AppDir/AppRun.
install -d %{buildroot}%{_bindir}
cat > %{buildroot}%{_bindir}/zen <<'EOF'
#!/bin/sh
# Keep the legacy single-profile layout instead of per-installation profiles.
export MOZ_LEGACY_PROFILES=1
# Lets Zen register itself as the default browser.
export MOZ_APP_LAUNCHER=zen
exec %{_libdir}/zen/zen "$@"
EOF
chmod 0755 %{buildroot}%{_bindir}/zen

for size in 16 32 48 64 128; do
    install -Dm 0644 browser/chrome/icons/default/default${size}.png \
        %{buildroot}%{_datadir}/icons/hicolor/${size}x${size}/apps/zen.png
done

# Upstream's entry carries an AppImage-only version marker.
install -d %{buildroot}%{_datadir}/applications
sed -e '/^X-AppImage-Version=/d' %{SOURCE1} \
    > %{buildroot}%{_datadir}/applications/zen.desktop

install -Dm 0644 %{SOURCE3} %{buildroot}%{_datadir}/licenses/%{name}/LICENSE

%check
# Upstream's desktop entry has cosmetic issues (a few translations use commas
# where the spec wants semicolons), so the report is informative only.
desktop-file-validate %{buildroot}%{_datadir}/applications/zen.desktop || :

%files
%license %{_datadir}/licenses/%{name}/LICENSE
%{_bindir}/zen
%{_libdir}/zen/
%{_datadir}/applications/zen.desktop
%{_datadir}/icons/hicolor/*/apps/zen.png

%changelog
* Mon Nov 16 2026 CairnCodeWorks <noreply@cairncodeworks.dev> - 1.24.2-0.1.beta
- Initial package
