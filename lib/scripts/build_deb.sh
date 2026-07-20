#!/bin/bash
set -e

# Change directory to project root relative to script location
cd "$(dirname "$0")/../.."

echo "Building Omoji release bundle..."
flutter build linux --release

# Setup directory structure
BUILD_DIR="build/debian"
PKG_DIR="${BUILD_DIR}/omoji_1.0.0_amd64"
rm -rf "${PKG_DIR}"
mkdir -p "${PKG_DIR}/DEBIAN"
mkdir -p "${PKG_DIR}/usr/bin"
mkdir -p "${PKG_DIR}/usr/lib/omoji"
mkdir -p "${PKG_DIR}/usr/share/applications"
mkdir -p "${PKG_DIR}/usr/share/pixmaps"

# Copy built bundle
cp -r build/linux/x64/release/bundle/* "${PKG_DIR}/usr/lib/omoji/"

# Create launcher script
cat << 'EOF' > "${PKG_DIR}/usr/bin/omoji"
#!/bin/sh
exec /usr/lib/omoji/omoji "$@"
EOF
chmod +x "${PKG_DIR}/usr/bin/omoji"

# Copy icon
if [ -f "lib/assets/imgs/app-logo.jpg" ]; then
    cp "lib/assets/imgs/app-logo.jpg" "${PKG_DIR}/usr/share/pixmaps/omoji.jpg"
fi

# Create desktop entry
cat << 'EOF' > "${PKG_DIR}/usr/share/applications/omoji.desktop"
[Desktop Entry]
Version=1.0.0
Name=Omoji
Comment=Acrylic emoji search and clipboard manager
Exec=/usr/bin/omoji
Icon=/usr/share/pixmaps/omoji.jpg
Terminal=false
Type=Application
Categories=Utility;
EOF

# Create Debian control file
cat << 'EOF' > "${PKG_DIR}/DEBIAN/control"
Package: omoji
Version: 1.0.0
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Kevin Manda <godlyttn@outlook.com>
Description: Acrylic glassmorphic emoji searcher and clipboard manager for Linux.
EOF

echo "Building debian package..."
dpkg-deb --build "${PKG_DIR}"

echo "Debian package created successfully: build/debian/omoji_1.0.0_amd64.deb"
