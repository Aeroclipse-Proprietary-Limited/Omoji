#!/bin/bash
set -e

# Change directory to project root relative to script location
cd "$(dirname "$0")/.."

is_running_omoji() {
    local pid="$1" process_name
    kill -0 "${pid}" 2>/dev/null || return 1
    [ -r "/proc/${pid}/comm" ] || return 1
    IFS= read -r process_name < "/proc/${pid}/comm" || return 1
    [ "${process_name}" = "omoji" ]
}

stop_running_omoji() {
    if ! command -v pgrep >/dev/null 2>&1; then
        echo "Error: pgrep is required to check for running Omoji instances." >&2
        return 1
    fi

    local pids pid still_running
    pids="$(pgrep -u "$(id -u)" -x omoji || true)"
    if [ -z "${pids}" ]; then
        echo "No running Omoji instances found."
        return
    fi

    echo "Stopping running Omoji instance(s) before updating..."
    while IFS= read -r pid; do
        if is_running_omoji "${pid}"; then
            if ! kill -TERM "${pid}" 2>/dev/null &&
                is_running_omoji "${pid}"; then
                echo "Error: could not stop Omoji process ${pid}." >&2
                return 1
            fi
        fi
    done <<< "${pids}"

    for attempt in 1 2 3 4 5; do
        still_running=0
        while IFS= read -r pid; do
            if is_running_omoji "${pid}"; then
                still_running=1
            fi
        done <<< "${pids}"
        if [ "${still_running}" -eq 0 ]; then
            break
        fi
        sleep 1
    done

    if [ "${still_running}" -ne 0 ]; then
        while IFS= read -r pid; do
            if is_running_omoji "${pid}"; then
                echo "Omoji process ${pid} did not exit; forcing it to stop."
                if ! kill -KILL "${pid}" 2>/dev/null &&
                    is_running_omoji "${pid}"; then
                    echo "Error: could not terminate Omoji process ${pid}." >&2
                    return 1
                fi
            fi
        done <<< "${pids}"

        sleep 1
        while IFS= read -r pid; do
            if is_running_omoji "${pid}"; then
                echo "Error: Omoji process ${pid} is still running; aborting update." >&2
                return 1
            fi
        done <<< "${pids}"
    fi

    echo "Omoji is stopped."
}

stop_running_omoji

echo "Building Omoji Linux release bundle..."
flutter build linux --release --dart-define=OMOJI_DEVELOPER_BUILD=true

INSTALL_DIR="${HOME}/.local/lib/omoji"
BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/.local/share/applications"
ICON_BASE="${HOME}/.local/share/icons/hicolor"
ICON_DIR_256="${ICON_BASE}/256x256/apps"
ICON_DIR_SCALABLE="${ICON_BASE}/scalable/apps"
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
    update-desktop-database "${APP_DIR}" >/dev/null 2>&1 || true
fi

# Ensure base index.theme exists before updating GTK icon cache to prevent cache invalid errors
if [ ! -f "${ICON_BASE}/index.theme" ]; then
    cat << EOF > "${ICON_BASE}/index.theme"
[Icon Theme]
Name=Hicolor
Comment=Fallback theme
Directories=256x256/apps,scalable/apps
EOF
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "${ICON_BASE}" >/dev/null 2>&1 || true
fi

echo "Omoji user-level installation complete!"
echo "Launcher: ${BIN_DIR}/omoji"
echo "Desktop File: ${APP_DIR}/omoji.desktop"