# Omoji

A lightweight, standalone desktop emoji picker built natively for Linux by EclipseBw. 

Omoji is designed to quickly pop up, let you search or select an emoji, and instantly copy it to your clipboard. Once it loses focus, it cleanly tucks itself away into the background until you need it again.

---

## Getting Started

Omoji runs natively across Linux desktop environments (such as Ubuntu, Fedora, Arch, Debian, and openSUSE). Follow the installation guide below to manually install the binary bundle and register it to a system-wide hotkey.

---

## How to Install Omoji

### Method A: Install the Debian Package (Recommended & Easiest)

If you are running a Debian-based system (such as Ubuntu, Debian, Pop!_OS, or Linux Mint), you can install the official `.deb` package. This will automatically copy the application files, register a global command, and configure a desktop menu shortcut.

1. Download the latest `.deb` package from the **[Releases](https://github.com/G-Titan/omoji/releases)** page.
2. Open your terminal in the directory where the package is located and install it:
   ```bash
   sudo apt install ./omoji_1.0.0_amd64.deb
   ```
3. Omoji is now installed! You can search and launch it from your desktop application launcher drawer.

---

### Method B: Manual Installation

If you prefer to install the application files manually:

#### 1. Copy the Application Files
Clone this repository, build the release bundle, and copy the standalone files into your user's local share directory:

```bash
mkdir -p ~/.local/share/omoji
cp -r build/linux/x64/release/bundle/* ~/.local/share/omoji/
```

#### 2. Add Omoji to Your Applications Menu

To make sure your operating system can index Omoji, show it in your system application drawer, and easily map it to shortcuts, you need to create a local desktop entry file.

Open a terminal and run:
Bash

nano ~/.local/share/applications/omoji.desktop

Paste the exact configuration block below into the editor:
Ini, TOML

[Desktop Entry]
Type=Application
Name=Omoji
Comment=Flutter Desktop Emoji Picker
Exec=/usr/bin/env sh -c "cd $HOME/.local/share/omoji && ./omoji"
Icon=face-smile
Terminal=false
Categories=Utility;

To save and exit Nano: Press CTRL + O, hit Enter to confirm, and then press CTRL + X.

Finally, give your operating system permission to execute the desktop entry by running:
Bash

chmod +x ~/.local/share/applications/omoji.desktop

Now, if you open your system's application launcher grid, you will find Omoji cleanly listed among your installed utilities!
3. Set Up Your Custom Keyboard Shortcut

Because Omoji functions like a quick utility panel, configuring a system hotkey provides the seamless "pop-up" workflow it was built for.

    Open your Linux System Settings.

    Navigate to Keyboard > Keyboard Shortcuts > View and Customize Shortcuts (this may be called Custom Shortcuts or Shortcuts depending on your desktop environment).

    Scroll to the bottom and click Custom Shortcuts to add a new one.

    Fill out the shortcut details:

        Name: Omoji

        Command: /home/YOUR_USERNAME/.local/share/omoji/omoji

        (Make sure to change YOUR_USERNAME to your actual Linux account name, as global desktop environment shortcuts don't always expand the $HOME variable properly).

    Click Set Shortcut and press your preferred key combination (popular choices include Super + . or Super + X).

Project Customization & Configuration

If you are developing or modifying Omoji, here is how the custom assets and font fallback systems are structured.
Adding Color Emoji Fonts

To ensure consistent, vibrant color emoji rendering across all Linux platforms (preventing your OS from falling back to monochrome line art), Omoji bundles the Noto Color Emoji asset.
1. Asset File Path

Download your preferred color emoji configuration (NotoColorEmoji-Regular.ttf) and make sure it is placed inside your local font path precisely at:
Plaintext

lib/assets/font/JetBrains_Mono,Noto_Color_Emoji/Noto_Color_Emoji/NotoColorEmoji-Regular.ttf

2. Pubspec Configuration (pubspec.yaml)

Register the font family in your project configurations under the flutter section:
YAML

flutter:
  uses-material-design: true

  fonts:
    - family: NotoColorEmoji
      fonts:
        - asset: lib/assets/font/JetBrains_Mono,Noto_Color_Emoji/Noto_Color_Emoji/NotoColorEmoji-Regular.ttf

3. Font Fallback Implementation (lib/main.dart)

Apply the color emoji font as a fallback typography rule globally across the app so it automatically intercepts all emoji characters:
Dart

class OmojiApp extends StatelessWidget {
  const OmojiApp({super.key});

  @override
  Widget build(BuildContext context) {
    const fallbackFonts = ['NotoColorEmoji'];

    return MaterialApp(
      title: 'Omoji',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamilyFallback: fallbackFonts,
        ),
        primaryTextTheme: ThemeData.dark().primaryTextTheme.apply(
          fontFamilyFallback: fallbackFonts,
        ),
      ),
      home: const OmojiHomeScreen(),
    );
  }
}

How to Use

    Press your assigned custom hotkey (Super + .).

    The Omoji panel will instantly appear right in the center of your screen with the search bar automatically focused.

    Start typing to filter emojis instantly, or scroll through the categories.

    Click on any emoji grid box—it will automatically copy that emoji to your system clipboard and instantly hide the window out of your way!

    Clicking anywhere outside the application window will also auto-hide the utility seamlessly.

Enjoy using Omoji!