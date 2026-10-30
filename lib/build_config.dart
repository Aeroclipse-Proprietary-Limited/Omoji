const bool isDeveloperBuild = bool.fromEnvironment(
  'OMOJI_DEVELOPER_BUILD',
  defaultValue: false,
);

// Allows a limited release build to unlock emoji insertion without enabling
// the developer-only clock, chat, or custom audio features.
const bool isEmojiSelectionUnlocked = bool.fromEnvironment(
  'OMOJI_EMOJIS_UNLOCKED',
  defaultValue: isDeveloperBuild,
);

const String omojiVersion = '1.2.6';
const String fullVersionUrl =
    'https://github.com/Aeroclipse-Proprietary-Limited/Omoji/releases';
const String registrationUrl = 'https://aeroclipse-bw.web.app/#editions';
