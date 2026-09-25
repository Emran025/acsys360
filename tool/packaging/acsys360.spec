Name:           acsys360
Version:        %{app_version}
Release:        1%{?dist}
Summary:        Arabic360 desktop programming environment
License:        LicenseRef-Proprietary
BuildArch:      x86_64
Requires:       gtk3, gcc, nasm

%description
Arabic-first desktop programming environment with a bundled Arabic C compiler.

%install
mkdir -p %{buildroot}/opt/acsys360
mkdir -p %{buildroot}/usr/share/applications
mkdir -p %{buildroot}/usr/share/icons/hicolor/512x512/apps
cp -a %{_buildrootdir}/opt/acsys360/. %{buildroot}/opt/acsys360/
cp -a %{_buildrootdir}/usr/share/applications/acsys360.desktop %{buildroot}/usr/share/applications/
cp -a %{_buildrootdir}/usr/share/icons/hicolor/512x512/apps/acsys360.png %{buildroot}/usr/share/icons/hicolor/512x512/apps/

%files
/opt/acsys360
/usr/share/applications/acsys360.desktop
/usr/share/icons/hicolor/512x512/apps/acsys360.png

%changelog
* Fri Sep 25 2026 acsys360 maintainers - %{version}-%{release}
- Initial native RPM package.
