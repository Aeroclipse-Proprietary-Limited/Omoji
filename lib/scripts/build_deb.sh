#!/bin/bash
set -e

# Change directory to project root relative to script location
cd "$(dirname "$0")/../.."

echo "Building Omoji release bundle..."
flutter build linux --release

# Setup directory structure
VERSION="1.1.0"
BUILD_DIR="build/debian"
PKG_DIR="${BUILD_DIR}/omoji_${VERSION}_amd64"
rm -rf "${PKG_DIR}"
mkdir -p "${PKG_DIR}/DEBIAN"
mkdir -p "${PKG_DIR}/usr/bin"
mkdir -p "${PKG_DIR}/usr/lib/omoji"
mkdir -p "${PKG_DIR}/usr/share/applications"
mkdir -p "${PKG_DIR}/usr/share/pixmaps"
mkdir -p "${PKG_DIR}/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${PKG_DIR}/usr/share/icons/hicolor/scalable/apps"

# Copy built bundle and prediction daemon scripts/data
cp -r build/linux/x64/release/bundle/* "${PKG_DIR}/usr/lib/omoji/"
mkdir -p "${PKG_DIR}/usr/lib/omoji/lib/scripts"
mkdir -p "${PKG_DIR}/usr/lib/omoji/lib/data"
cp -r lib/scripts/* "${PKG_DIR}/usr/lib/omoji/lib/scripts/"
cp -r lib/data/* "${PKG_DIR}/usr/lib/omoji/lib/data/"

# Create launcher script
cat << 'EOF' > "${PKG_DIR}/usr/bin/omoji"
#!/bin/sh
exec /usr/lib/omoji/omoji "$@"
EOF
chmod +x "${PKG_DIR}/usr/bin/omoji"

# Copy icon files
if [ -f "lib/assets/imgs/app-logo.png" ]; then
    cp "lib/assets/imgs/app-logo.png" "${PKG_DIR}/usr/share/pixmaps/omoji.png"
    cp "lib/assets/imgs/app-logo.png" "${PKG_DIR}/usr/share/icons/hicolor/256x256/apps/omoji.png"
    cp "lib/assets/imgs/app-logo.png" "${PKG_DIR}/usr/share/icons/hicolor/scalable/apps/omoji.png"
fi

if [ -f "lib/assets/imgs/app-logo.jpg" ]; then
    cp "lib/assets/imgs/app-logo.jpg" "${PKG_DIR}/usr/share/pixmaps/omoji.jpg"
fi

# Create desktop entry
cat << EOF > "${PKG_DIR}/usr/share/applications/omoji.desktop"
[Desktop Entry]
Version=1.0
Name=Omoji
Comment=Acrylic emoji search and clipboard manager
Exec=/usr/bin/omoji
Icon=omoji
Terminal=false
Type=Application
Categories=Utility;
StartupWMClass=omoji
EOF

# Create Debian control file
cat << EOF > "${PKG_DIR}/DEBIAN/control"
Package: omoji
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Kevin Manda <godlyttn@outlook.com>
Description: Acrylic glassmorphic emoji searcher and clipboard manager for Linux.
EOF

echo "Building debian package..."
dpkg-deb --build "${PKG_DIR}"

echo "Debian package created successfully: build/debian/omoji_${VERSION}_amd64.deb"
