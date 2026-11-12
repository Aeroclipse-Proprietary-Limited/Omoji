# Changelog

Notable changes to Omoji are recorded here.

## [Unreleased]

### Changes since v1.2.5

- Added Omoji Chat and AI-assisted emoji prediction, with local and cloud model
  options in Settings.
- Expanded the emoji catalog with a Symbols & Signs category, including caution,
  warning, safety, traffic, information and directional symbols.
- Added calendar import for iCalendar (`.ics`) and common calendar CSV files.
  Import remains unavailable until an account is attached; Firebase sign-in is
  still a placeholder.
- Expanded to-do and event controls with notes, completion status, a Delayed
  filter, and overdue rescheduling by 24 hours or a chosen date and time.
- Added log-level filters and a `CHANGELOG.md` view to the existing Logs button.
- Added an Animations switch and a Run at login option. When enabled, Omoji
  starts hidden with a system tray menu for Exit, Private Mode, Snap Store
  updates, and Chat. Chat is disabled unless Super Agents is enabled.
- Improved clipboard and auto-paste handling across Linux, macOS and Windows,
  including Linux Wayland and X11 fallback paths.
- Added accent background effects, a sticky Settings header, app-version display,
  and an update-available indicator linked to release information.
- Added disabled account sign-in controls while the Firebase login flow is
  pending. No account or licence authentication is implemented yet.
- Added PayPal and ETH donation options and full-version prompts for gated Clock
  tools and custom alarm sounds. Donations are optional and separate from access.
- Updated application icons, Linux packaging and installation scripts, Linux and
  macOS setup documentation, and Windows desktop build automation.
- Added update checks using GitHub Releases and the Snap Store. The check sends
  no clipboard or app-usage data.
- Added local backup export and import for settings, clipboard history, alarms,
  to-dos, timers and stopwatch data; later removed those controls in preparation
  for future cloud-managed backups.
- Hardened hotkey registration against command injection, passed alarm text to
  macOS notifications as arguments, moved prediction-daemon communication to a
  per-user Unix socket, and restricted settings, log and update-cache file
  permissions on Unix.
- Changed alarm shutdown to stop only the audio process started by Omoji.
