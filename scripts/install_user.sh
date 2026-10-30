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

if ! command -v flutter >/dev/null 2>&1; then
    if [ -x "${HOME}/Documents/Dev-portal/flutter/bin/flutter" ]; then
        export PATH="${HOME}/Documents/Dev-portal/flutter/bin:${PATH}"
    fi
fi

echo "Building Omoji Premium Debian package..."
OMOJI_DEVELOPER_BUILD=true scripts/build_deb.sh

DEB_FILE="${PWD}/build/debian/omoji_1.2.6_amd64.deb"
if [ ! -f "${DEB_FILE}" ]; then
    echo "Error: expected package was not created: ${DEB_FILE}" >&2
    exit 1
fi
if ! command -v sudo >/dev/null 2>&1; then
    echo "Error: sudo is required to install the system package." >&2
    exit 1
fi

echo "Installing Premium package system-wide..."
sudo dpkg -i "${DEB_FILE}"
rm -f "${DEB_FILE}"

# An older user-level installation may leave a higher-priority desktop entry
# and PATH wrapper pointing at ~/.local/lib/omoji. Keep those launch points,
# but redirect them to the newly installed system package.
USER_BIN_DIR="${HOME}/.local/bin"
USER_APP_DIR="${HOME}/.local/share/applications"
mkdir -p "${USER_BIN_DIR}" "${USER_APP_DIR}"

cat << 'EOF' > "${USER_BIN_DIR}/omoji"
#!/bin/sh
exec /usr/bin/omoji "$@"
EOF
chmod +x "${USER_BIN_DIR}/omoji"

cat << 'EOF' > "${USER_APP_DIR}/omoji.desktop"
[Desktop Entry]
Version=1.0
Name=Omoji
Comment=Acrylic emoji search and clipboard manager
Exec=/usr/bin/omoji
Icon=omoji
Terminal=false
Type=Application
Categories=Utility;
StartupWMClass=com.aeroclipse.omoji
EOF
chmod +x "${USER_APP_DIR}/omoji.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${USER_APP_DIR}" >/dev/null 2>&1 || true
fi

echo "Omoji Premium is installed. The generated .deb has been deleted."
echo "Desktop and command-line launchers now use /usr/bin/omoji."
