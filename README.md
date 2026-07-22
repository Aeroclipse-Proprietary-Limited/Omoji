# Omoji

A lightweight, glassmorphic desktop emoji picker and clipboard history manager built natively for **Linux** & **macOS** by **Aeroclipse Proprietary Limited**.

Omoji is designed to pop up instantly via a keyboard shortcut (`Super + .` / `Cmd + .`), let you search and copy emojis or manage your clipboard history, and auto-inject your selection directly into your active window.

---

## ✨ Features

- **Clipboard History**: Tracks copied text snippets with inline editing, pinning, copying, and deletion.
- **Color Emoji Picker**: Fast, categorized emoji search with automatic color fallback typography.
- **Instant Search Focus**: Typing instantly redirects input into the search bar without requiring an initial click.
- **Auto-Injection & Auto-Paste**: Automatically types or pastes selected emojis into your active application window (Wayland `wtype` on Linux, AppleScript `Cmd+V` on macOS).
- **Glassmorphic UI**: Premium acrylic visual aesthetic with full Dark, Light, and System theme persistence.
- **Privacy Mode**: Toggleable privacy mode to halt clipboard tracking whenever needed.

---

## 🚀 Installation & Setup

### 🐧 Linux

#### 1. Debian / Ubuntu / Pop!_OS / Linux Mint (`.deb`)

1. Download **`omoji_1.0.0_amd64.deb`** from **[Releases](https://github.com/Aeroclipse-Proprietary-Limited/Omoji/releases)**.
2. Open terminal in your downloads folder and install:
   ```bash
   sudo apt install ./omoji_1.0.0_amd64.deb
   ```

#### 2. Fedora / Red Hat / openSUSE / RHEL (`.rpm`)

1. Download **`omoji-1.0.0-1.x86_64.rpm`** from **[Releases](https://github.com/Aeroclipse-Proprietary-Limited/Omoji/releases)**.
2. Open terminal in your downloads folder and install:
   ```bash
   sudo dnf install ./omoji-1.0.0-1.x86_64.rpm
   # OR for RPM-only systems:
   sudo rpm -i ./omoji-1.0.0-1.x86_64.rpm
   ```

#### 3. Custom Hotkey Setup (Linux)
- Open **System Settings** -> **Keyboard** -> **Keyboard Shortcuts** -> **Custom Shortcuts**.
- Add shortcut:
  - **Name**: `Omoji`
  - **Command**: `omoji` (or `/usr/bin/omoji`)
- Set key combination (e.g., `Super + .`).

---

### 🍏 macOS

#### 1. Installation
1. Download or build `omoji.app` from **[Releases](https://github.com/Aeroclipse-Proprietary-Limited/Omoji/releases)**.
2. Move `omoji.app` into your **`/Applications`** folder.

#### 2. macOS Accessibility Permission (Required for Auto-Paste)
To allow Omoji to auto-paste emojis directly into active apps:
1. Open **System Settings** -> **Privacy & Security** -> **Accessibility**.
2. Enable **Omoji** in the allowed applications list.

#### 3. Custom Hotkey Setup (macOS)
- Set up a hotkey using **System Settings** -> **Keyboard** -> **Keyboard Shortcuts**, or via tools like **Raycast** / **Alfred** / **Shortcuts.app** mapped to launch `omoji.app` with `Cmd + .`.

---

## 🛠 Building from Source

### Linux (Ubuntu, Debian, Fedora, Red Hat, Arch)

```bash
git clone git@github.com:Aeroclipse-Proprietary-Limited/Omoji.git
cd Omoji
flutter build linux --release
```

- **Generate `.deb` Package**:
  ```bash
  ./lib/scripts/build_deb.sh
  ```

- **Generate `.rpm` Package**:
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