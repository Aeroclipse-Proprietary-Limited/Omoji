# Omoji

> A lightweight, glassmorphic desktop emoji picker and clipboard history manager — built natively for **Linux** and **macOS** by **Aeroclipse Proprietary Limited**.

Omoji opens with a keyboard shortcut (`Super + X` on Linux / `Cmd + .` on macOS) so you can instantly search and copy emojis, manage your clipboard history, and paste selections directly into the active application — no mouse required.

---

## Features

| Feature | Description |
|---|---|
| 📋 Clipboard History | Edit, pin, copy, and delete clipboard entries with ease |
| 😀 Emoji Search | Fast, full-color emoji search with instant results |
| ⌨️ Auto-Focus | Search begins typing immediately — no initial click needed |
| 🖱️ Auto-Paste | Automatic typing and paste support for Linux and macOS |
| 🎨 Themes | Dark, light, and system-synced theme options |
| 🔒 Privacy Mode | Pause clipboard tracking at any time |
| 🔔 Alarms & Timers | Built-in alarm, timer, and stopwatch tools |
| 📦 Backup & Import | Export and import your clipboard history, settings, and more |

---

## Get Omoji

### Prepackaged App

Install directly from the **Snap Store** or download a `.deb` / `.rpm` package from **GitHub Releases**:

[![Get it from the Snap Store](https://snapcraft.io/static/images/badges/en/snap-store-black.svg)](https://snapcraft.io/omoji)

**[GitHub Releases →](https://github.com/Aeroclipse-Proprietary-Limited/Omoji/releases)**

Install a downloaded `.deb` package:

```bash
sudo apt install ./omoji_1.2.5_amd64.deb
```

Install a downloaded `.rpm` package:

```bash
sudo dnf install ./omoji-1.2.5-1.x86_64.rpm
```

> **Note:** The Snap Store determines availability and any price shown there. The `.deb` and `.rpm` packages use the consumer feature set — Settings and Clock tools are locked. Import and export remain available without a purchase.

---

### Build from Source (Full Developer Version)

Building from source unlocks the complete feature set — including Settings and Clock tools — at no cost.

**Prerequisites:** [Flutter](https://docs.flutter.dev/get-started/install) installed for your platform.

```bash
git clone https://github.com/Aeroclipse-Proprietary-Limited/Omoji.git
cd Omoji
flutter pub get
```

#### Linux

Build and install for your current user (no root required):

```bash
./scripts/install_user.sh
~/.local/bin/omoji
```

Build consumer-flavour installable packages (Settings and Clock locked; backup/import/export still available):

```bash
./scripts/build_deb.sh    # Output: build/debian/
./scripts/build_rpm.sh    # Output: build/rpm/RPMS/  — requires rpmbuild
```

#### macOS

```bash
flutter build macos --release
```

Move the generated `build/macos/Build/Products/Release/omoji.app` into `/Applications`. Enable Omoji under **System Settings → Privacy & Security → Accessibility** to allow automatic paste.

---

## Backup & Data

Omoji's backup includes: settings, clipboard history, alarms, to-dos, timer state, and stopwatch state. Clipboard text is included. Custom alarm sound files are **not** copied — only their configured file path is saved.

---

## Report Issues & Contribute

We welcome bug reports, feature requests, and contributions from the community.

- **🐛 Report a bug or request a feature:** [Open a GitHub issue](https://github.com/Aeroclipse-Proprietary-Limited/Omoji/issues/new). Include your OS, Omoji version, steps to reproduce, and any relevant error output.
- **🔧 Contribute code or documentation:** Fork the repository, create a focused branch, make and test your change, then open a [pull request](https://github.com/Aeroclipse-Proprietary-Limited/Omoji/compare). Describe the problem addressed and the testing performed.
- **📧 Email feedback:** [godlyttn@outlook.com](mailto:godlyttn@outlook.com)

Run the project checks before submitting any changes:

```bash
flutter analyze
flutter test
```

See [Contributing.md](Contributing.md) for full contribution guidelines.

---

## Website (Firebase Hosting)

The static marketing site lives in `web/` and is configured as the Firebase Hosting public directory. Deploy from the repository root:

```bash
firebase login
firebase deploy --project aeroclipse-bw --only hosting
```

---

## Careers at Aeroclipse

We are a human-driven company — no algorithm or AI is used in our hiring process.

Career applications are sent as an email to [godlyttn@outlook.com](mailto:godlyttn@outlook.com) with your CV attached.

---

## License & Credits

Developed and maintained by **Aeroclipse Proprietary Limited**.  
Licensed under the [GPL-3.0 License](license.md).