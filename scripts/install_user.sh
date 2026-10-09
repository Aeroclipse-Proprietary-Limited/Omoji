#!/bin/bash
set -e

# Change directory to project root relative to script location
cd "$(dirname "$0")/.."

echo "Building Omoji Linux release bundle..."
flutter build linux --release

INSTALL_DIR="${HOME}/.local/lib/omoji"
BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
ICON_DIR_256="${HOME}/.local/share/icons/hicolor/256x256/apps"
ICON_DIR_SCALABLE="${HOME}/.local/share/icons/hicolor/scalable/apps"
PIXMAP_DIR="${HOME}/.local/share/pixmaps"

echo "Creating user directories..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${BIN_DIR}"
mkdir -p "${APP_DIR}"
mkdir -p "${ICON_DIR_256}"
mkdir -p "${ICON_DIR_SCALABLE}"
mkdir -p "${PIXMAP_DIR}"

echo "Installing release bundle into ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}"/*
cp -r build/linux/x64/release/bundle/* "${INSTALL_DIR}/"

mkdir -p "${INSTALL_DIR}/lib/scripts"
mkdir -p "${INSTALL_DIR}/lib/data"
cp scripts/emoji_prediction_daemon.py scripts/omoji_paste.py "${INSTALL_DIR}/lib/scripts/"
cp -r lib/data/* "${INSTALL_DIR}/lib/data/"

echo "Creating binary executable wrapper in ${BIN_DIR}/omoji..."
cat << EOF > "${BIN_DIR}/omoji"
#!/bin/sh
exec "${INSTALL_DIR}/omoji" "\$@"
EOF
chmod +x "${BIN_DIR}/omoji"

echo "Installing icons..."
if [ -f "lib/assets/imgs/app-logo.png" ]; then
    cp "lib/assets/imgs/app-logo.png" "${PIXMAP_DIR}/omoji.png"
    cp "lib/assets/imgs/app-logo.png" "${ICON_DIR_256}/omoji.png"
    cp "lib/assets/imgs/app-logo.png" "${ICON_DIR_SCALABLE}/omoji.png"
fi

if [ -f "lib/assets/imgs/app-logo.jpg" ]; then
    cp "lib/assets/imgs/app-logo.jpg" "${PIXMAP_DIR}/omoji.jpg"
fi

echo "Creating desktop launcher in ${APP_DIR}/omoji.desktop..."
cat << EOF > "${APP_DIR}/omoji.desktop"
[Desktop Entry]
Version=1.0
Name=Omoji
Comment=Acrylic emoji search and clipboard manager
Exec=${BIN_DIR}/omoji
Icon=omoji
Terminal=false
Type=Application
Categories=Utility;
StartupWMClass=omoji
EOF

chmod +x "${APP_DIR}/omoji.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${APP_DIR}" || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor" || true
fi

echo "Omoji user-level installation complete!"
echo "Launcher: ${BIN_DIR}/omoji"
echo "Desktop File: ${APP_DIR}/omoji.desktop"
