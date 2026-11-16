%global upstream_tag v2.16.0

Name:           protonup-qt
Version:        2.16.0
Release:        1%{?dist}
Summary:        Install Wine- and Proton-based compatibility tools
License:        GPL-3.0-only
URL:            https://github.com/DavidoTek/ProtonUp-Qt

Source0:        %{url}/archive/refs/tags/%{upstream_tag}.tar.gz
# Upstream hard-depends on inputs==0.5 for gamepad navigation and Fedora does
# not package it. Vendoring it keeps that feature instead of silently dropping
# it; see the %install section for where it goes.
Source1:        https://files.pythonhosted.org/packages/source/i/inputs/inputs-0.5.tar.gz

BuildArch:      noarch

BuildRequires:  desktop-file-utils
BuildRequires:  python3-devel
# Only needed by %check, which verifies that the vendored module is importable.
BuildRequires:  python3-vdf

# Fedora's python3-pyside6 is built from C++ bindings, so it does not provide
# `python3dist(pyside6)`. PySide6 is therefore dropped from the wheel metadata
# below and required by RPM name here instead.
Requires:       python3-pyside6

Provides:       bundled(python3dist(inputs)) = 0.5

%description
ProtonUp-Qt is a graphical user interface to install and manage Wine- and
Proton-based compatibility tools such as GE-Proton, Proton-Tkg and Luxtorpeda
for Steam, Lutris, Heroic Games Launcher, Bottles and WineZGUI.

It can also list the games of a launcher and show which compatibility tool
each one uses.

%prep
%autosetup -n ProtonUp-Qt-%{version}

tar -xzf %{SOURCE1} -C %{_builddir}

# Use what Fedora actually ships. Left unpatched, these pins end up in the
# wheel's Requires-Dist metadata, from which RPM generates Requires that no
# repository can satisfy (python3dist(pyside6-essentials), python3dist(inputs)
# and two git URLs), leaving the package uninstallable.
#
#  * PySide6 is removed here and required by RPM name in the header instead,
#    because python3-pyside6 provides no python3dist() name;
#  * vdf and steam are pinned to git tags that are not packaged, while the APIs
#    used here (vdf.loads/dump/binary_*, steam.utils.appcache.parse_appinfo) are
#    unchanged between those tags and the packaged releases;
#  * inputs is removed from the dependency list because it is vendored below.
sed -i \
    -e '/"PySide6-Essentials>=6.3.0",/d' \
    -e 's|"vdf @ git+https://github.com/solsticegamestudios/vdf.git@v4.0"|"vdf>=3.3"|' \
    -e 's|"steam @ git+https://github.com/solsticegamestudios/steam.git@v2.0.0-alpha1"|"steam>=1.6"|' \
    -e '/"inputs==0.5",/d' \
    pyproject.toml

# Upstream's desktop entry calls a binary name that only exists in the AppImage.
sed -i 's|^Exec=net.davidotek.pupgui2$|Exec=protonup-qt|' \
    share/applications/net.davidotek.pupgui2.desktop

%generate_buildrequires
%pyproject_buildrequires

%build
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files pupgui2

install -d %{buildroot}%{_datadir}/applications
install -m 0644 share/applications/net.davidotek.pupgui2.desktop \
    %{buildroot}%{_datadir}/applications/

for size in 64 128 256; do
    install -Dm 0644 share/icons/hicolor/${size}x${size}/apps/net.davidotek.pupgui2.png \
        %{buildroot}%{_datadir}/icons/hicolor/${size}x${size}/apps/net.davidotek.pupgui2.png
done

install -Dm 0644 share/metainfo/net.davidotek.pupgui2.appdata.xml \
    %{buildroot}%{_datadir}/metainfo/net.davidotek.pupgui2.appdata.xml

install -Dm 0644 LICENSE %{buildroot}%{_datadir}/licenses/%{name}/LICENSE
install -Dm 0644 %{_builddir}/inputs-0.5/LICENSE \
    %{buildroot}%{_datadir}/licenses/%{name}/LICENSE.inputs

# Vendored inputs, deliberately outside the system site-packages so that it
# cannot collide with a future python3-inputs. A .pth file adds the directory
# to sys.path, which keeps upstream's generated entry point working unchanged.
install -d %{buildroot}%{_datadir}/protonup-qt/vendor
install -m 0644 %{_builddir}/inputs-0.5/inputs.py \
    %{buildroot}%{_datadir}/protonup-qt/vendor/inputs.py

cat > %{buildroot}%{python3_sitelib}/protonup-qt-vendor.pth <<'EOF'
%{_datadir}/protonup-qt/vendor
EOF

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/net.davidotek.pupgui2.desktop

# The vendored module must be importable, and the rewritten vdf pin must point
# at something that actually exists in the build root.
PYTHONPATH=%{buildroot}%{python3_sitelib}:%{buildroot}%{_datadir}/protonup-qt/vendor \
    %{__python3} -c 'import inputs, vdf'

%files -f %{pyproject_files}
%license %{_datadir}/licenses/%{name}/LICENSE
%license %{_datadir}/licenses/%{name}/LICENSE.inputs
%{_datadir}/applications/net.davidotek.pupgui2.desktop
%{_datadir}/icons/hicolor/*/apps/net.davidotek.pupgui2.png
%{_datadir}/metainfo/net.davidotek.pupgui2.appdata.xml
%{_datadir}/protonup-qt/vendor/inputs.py
%{python3_sitelib}/protonup-qt-vendor.pth

%changelog
* Mon Nov 16 2026 CairnCodeWorks <noreply@cairncodeworks.dev> - 2.16.0-1
- Initial package
