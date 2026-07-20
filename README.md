# Omoji

A lightweight, glassmorphic desktop emoji picker and clipboard history manager built natively for Linux by **Aeroclipse Proprietary Limited**.

Omoji is designed to pop up instantly via a keyboard shortcut (`Super + .`), let you search and copy emojis or manage your clipboard history, and auto-inject your selection directly into your active window.

---

## ✨ Features

- **Clipboard History**: Tracks copied text snippets with inline editing, pinning, copying, and deletion.
- **Color Emoji Picker**: Fast, categorized emoji search with automatic color fallback typography.
- **Wayland Auto-Injection**: Automatically types selected emojis or clipboard snippets into your active application window.
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

1. Open your Linux **System Settings** -> **Keyboard** -> **Keyboard Shortcuts** -> **Custom Shortcuts**.
2. Add a new shortcut:
   - **Name**: `Omoji`
   - **Command**: `omoji` (or `/usr/bin/omoji`)
3. Set your preferred key combination (e.g., `Super + .` or `Super + X`).

---

## 🛠 Building from Source

```bash
git clone git@github.com:Aeroclipse-Proprietary-Limited/Omoji.git
cd Omoji
flutter build linux --release
```

To generate the `.deb` package installer locally:
```bash
chmod +x lib/scripts/build_deb.sh
./lib/scripts/build_deb.sh
```

---

## 📄 License & Credits

Developed and maintained by **Aeroclipse Proprietary Limited**. Licensed under the [GPL-3.0 License](license.md).