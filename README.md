# Omoji

A lightweight, glassmorphic desktop emoji picker and clipboard history manager built natively for Linux & macOS by **Aeroclipse Proprietary Limited**.

Omoji is designed to pop up instantly via a keyboard shortcut (`Super + .` / `Cmd + .`), let you search and copy emojis or manage your clipboard history, and auto-inject your selection directly into your active window.

---

## ✨ Features

- **Clipboard History**: Tracks copied text snippets with inline editing, pinning, copying, and deletion.
- **Color Emoji Picker**: Fast, categorized emoji search with automatic color fallback typography.
- **Auto-Injection & Auto-Paste**: Automatically types or pastes selected emojis into your active application window (Wayland `wtype` on Linux, AppleScript `Cmd+V` on macOS).
- **Glassmorphic UI**: Premium acrylic visual aesthetic with full Dark, Light, and System theme persistence.
- **Privacy Mode**: Toggleable privacy mode to halt clipboard tracking whenever needed.

---

## 🚀 Installation

### Debian / Ubuntu / Pop!_OS / Linux Mint (Recommended)

1. Download the latest **`omoji_1.0.0_amd64.deb`** package from **[Releases](https://github.com/Aeroclipse-Proprietary-Limited/Omoji/releases)**.
2. Open your terminal in the download directory and install it:
   ```bash
   sudo apt install ./omoji_1.0.0_amd64.deb
   ```
3. Omoji is now installed! You can launch it from your desktop application grid or set up a hotkey below.

---

## ⌨️ Custom Keyboard Shortcut

To get the seamless "pop-up" workflow:

1. Open your **System Settings** -> **Keyboard** -> **Keyboard Shortcuts**.
2. Add a new shortcut:
   - **Name**: `Omoji`
   - **Command**: `omoji` (or `/usr/bin/omoji`)
3. Set your preferred key combination (e.g., `Super + .` or `Cmd + .`).

---

## 🛠 Building from Source

### Linux (Ubuntu, Debian, Fedora, Red Hat, Arch)

```bash
git clone git@github.com:Aeroclipse-Proprietary-Limited/Omoji.git
cd Omoji
flutter build linux --release
```

- **Generate `.deb` Package (Debian / Ubuntu)**:
  ```bash
  ./lib/scripts/build_deb.sh
  ```

- **Generate `.rpm` Package (Fedora / Red Hat / openSUSE)**:
  ```bash
  ./lib/scripts/build_rpm.sh
  ```

### macOS

```bash
git clone git@github.com:Aeroclipse-Proprietary-Limited/Omoji.git
cd Omoji
flutter build macos --release
```

---

## 📄 License & Credits

Developed and maintained by **Aeroclipse Proprietary Limited**. Licensed under the [GPL-3.0 License](license.md).