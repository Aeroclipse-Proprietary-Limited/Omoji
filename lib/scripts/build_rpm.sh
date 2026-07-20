#!/bin/bash
set -e

# Change directory to project root relative to script location
cd "$(dirname "$0")/../.."

echo "Building Omoji Linux release bundle..."
flutter build linux --release

# Verify rpmbuild is available
if ! command -v rpmbuild &> /dev/null; then
    echo "Notice: rpmbuild is not installed on this machine. To compile RPM packages locally, install rpm (e.g. sudo apt install rpm)."
    echo "The RPM spec script has been prepared in lib/scripts/build_rpm.sh for Red Hat/Fedora/CI build environments."
    exit 0
fi

PACKAGE_NAME="omoji"
VERSION="1.0.0"
BUILD_DIR="build/rpm"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Copy release bundle into SOURCES
mkdir -p "$BUILD_DIR/SOURCES/bundle"
cp -r build/linux/x64/release/bundle/* "$BUILD_DIR/SOURCES/bundle/"

# Create spec file
cat << SPECEOF > "$BUILD_DIR/SPECS/omoji.spec"
Name:           omoji
Version:        1.0.0
Release:        1%{?dist}
Summary:        A lightweight, glassmorphic desktop emoji picker & clipboard manager

License:        GPLv3
URL:            https://github.com/Aeroclipse-Proprietary-Limited/Omoji

%description
Omoji is a standalone desktop emoji picker & clipboard history manager built natively for Linux.

%install
mkdir -p %{buildroot}/usr/lib/omoji
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/applications

cp -r %{_sourcedir}/bundle/* %{buildroot}/usr/lib/omoji/

cat << 'INNER_EOF' > %{buildroot}/usr/share/applications/omoji.desktop
[Desktop Entry]
Type=Application
Name=Omoji
Comment=Flutter Desktop Emoji Picker & Clipboard Manager
Exec=/usr/bin/omoji
Icon=face-smile
Terminal=false
Categories=Utility;
INNER_EOF

cat << 'INNER_EOF' > %{buildroot}/usr/bin/omoji
#!/bin/bash
cd /usr/lib/omoji
./omoji "\$@"
INNER_EOF
chmod +x %{buildroot}/usr/bin/omoji

%files
/usr/lib/omoji
/usr/bin/omoji
/usr/share/applications/omoji.desktop

%changelog
* Mon Jul 20 2026 Aeroclipse Proprietary Limited <support@aeroclipse.com> - 1.0.0-1
- Initial release of Omoji RPM package
SPECEOF

echo "Building RPM package..."
rpmbuild --define "_topdir $(pwd)/$BUILD_DIR" -bb "$BUILD_DIR/SPECS/omoji.spec"

echo "RPM package created successfully inside $BUILD_DIR/RPMS/"
