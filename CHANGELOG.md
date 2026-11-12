# Changelog

Notable changes to Omoji are recorded here.

## [Unreleased]

Changes in the current codebase compared with v1.2.5.

### Features

- Added Omoji Chat with local and cloud model/provider options, conversation
  export, and Super Agents controls in Settings.
- Added AI-assisted emoji prediction and expanded the emoji catalog, including
  recent Unicode additions and a Symbols & Signs category with caution, safety,
  traffic, information, mathematical, and directional symbols.
- Expanded to-do and event management with a notes reading view, event
  completion, a Delayed filter, and overdue rescheduling by 24 hours or a chosen
  date and time.
- Added audio ducking for alarms and timers, configurable alarm looping, and
  custom alarm sounds in eligible builds.
- Added full-version prompts for gated Clock tools, emoji selection, AI chat,
  and custom alarm sounds, with links to Omoji release or registration pages.

### Settings and app behavior

- Added an Animations on/off switch in place of the former latency controls.
- Added Run at login control. When enabled, Omoji starts hidden in the
  background; its tray menu provides Exit, Private Mode, a Snap Store link, and
  Chat. Chat is disabled unless Super Agents is enabled.
- Added an account placeholder with a disabled Login button. Firebase sign-in
  and licence-key authentication are not implemented yet.
- Expanded the existing Logs button with INFO/WARN/ERROR filters and a view of
  `CHANGELOG.md`.
- Added accent background effects, a sticky Settings header, an app-version
  display, and an update-available indicator.
- Added PayPal and ETH donation links and an ETH wallet-copy confirmation.
  Donations are optional and separate from feature access.
- Made Settings available in free builds while keeping selected features gated.
- Added daily update checks against GitHub Releases and the Snap Store. The
  check sends no clipboard contents or app-usage data.
- Improved clipboard and auto-paste handling across Linux, macOS, and Windows,
  with Linux Wayland and X11 fallback paths.

### Security and reliability

- Replaced generated shell commands in Linux hotkey registration with validated
  shortcut values passed directly to `gsettings`.
- Passed alarm and to-do notification text to macOS notifications as arguments
  so text cannot change the AppleScript being executed.
- Moved the emoji prediction daemon channel from loopback TCP to a per-user Unix
  socket, with restricted socket and runtime-directory permissions.
- Restricted settings, log, and update-cache files and directories to the
  current user on Unix systems.
- Changed alarm shutdown to stop only the audio process Omoji started.
- Added security reporting guidance and a Terms and Conditions notice to the
  security policy.

### Distribution and project documentation

- Updated Linux packaging and installation scripts, added Flatpak/Snap
  distribution configuration, and expanded Linux/macOS setup documentation.
- Added a Windows desktop build workflow.
- Added repository contribution guidance and a community Code of Conduct.
- Updated application icons and Omoji branding assets.

### Removed

- Added local backup export/import for settings, clipboard history, alarms,
  to-dos, timers, and stopwatch data, then removed those controls in preparation
  for possible cloud-managed backups. Cloud backup is not implemented yet.
