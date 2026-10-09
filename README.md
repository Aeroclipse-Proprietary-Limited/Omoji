# Omoji

A lightweight, glassmorphic desktop emoji picker and clipboard history manager built natively for **Linux** and **macOS** by **Aeroclipse Proprietary Limited**.

Omoji opens with a keyboard shortcut (`Super + X` / `Cmd + .`) so you can search and copy emojis, manage clipboard history, and paste selections into the active application.

## Features

- Clipboard history with editing, pinning, copying, and deletion.
- Fast emoji search with color emoji rendering.
- Search focus without an initial click.
- Automatic typing and paste support for Linux and macOS.
- Dark, light, and system theme options.
- Privacy mode to pause clipboard tracking.

## Get Omoji

### Prepackaged app

Users can install the packaged Linux app from the [Omoji Snap Store listing](https://snapcraft.io/omoji). The store determines availability and any price shown there; the source build does not require a store purchase.

For Debian- and Fedora-family distributions, `.deb` and `.rpm` packages can be built using the instructions below. Check [GitHub Releases](https://github.com/Aeroclipse-Proprietary-Limited/Omoji/releases) for prebuilt package downloads when they are published. GitHub release assets in this public repository are downloadable without a store purchase.

Install a downloaded package with:

```bash
sudo apt install ./omoji_1.2.5_amd64.deb
```

or:

```bash
sudo dnf install ./omoji-1.2.5-1.x86_64.rpm
```

### Build a non-paywalled version from source

Developers and users can build and install Omoji directly from source without purchasing the store version. The repository contains no in-app purchase or paywall enforcement.

Install Flutter for your platform, then clone the public source repository:

```bash
git clone https://github.com/Aeroclipse-Proprietary-Limited/Omoji.git
cd Omoji
flutter pub get
```

#### Linux

Build and install for your current user without root access. The installer builds the release bundle and places the runtime helper scripts alongside it:

```bash
./scripts/install_user.sh
~/.local/bin/omoji
```

Build installable packages:

```bash
./scripts/build_deb.sh
./scripts/build_rpm.sh
```

The `.deb` is written to `build/debian/`; RPM output is written under `build/rpm/RPMS/`. Building an RPM requires `rpmbuild`.

#### macOS

```bash
flutter build macos --release
```

Move the generated `build/macos/Build/Products/Release/omoji.app` into `/Applications`. Enable Omoji under **System Settings → Privacy & Security → Accessibility** if you want to use automatic paste.

## Report issues and contribute

- **Report a bug or request a feature:** [Open a GitHub issue](https://github.com/Aeroclipse-Proprietary-Limited/Omoji/issues/new). Include your operating system, Omoji version, steps to reproduce, and any relevant error output.
- **Contribute code or documentation:** Fork the repository, create a focused branch, make and test your change, then open a [pull request](https://github.com/Aeroclipse-Proprietary-Limited/Omoji/compare). Please describe the problem addressed and the testing performed.
- **Email feedback:** [godlyttn@outlook.com](mailto:godlyttn@outlook.com).

Run the project checks before submitting changes:

```bash
flutter analyze
flutter test
```

## Website (Firebase Hosting)

The static marketing site lives in `web/` and is configured as the Firebase Hosting public directory. After selecting the Firebase project, deploy it from the repository root:

```bash
firebase login
firebase deploy --project aeroclipse-bw --only hosting
```

Career applications are prepared as an email to `godlyttn@outlook.com`; applicants attach their CV in their own email app. Update the destination in `web/script.js` if it changes.

## License and credits

Developed and maintained by **Aeroclipse Proprietary Limited**. Licensed under the [GPL-3.0 License](license.md).