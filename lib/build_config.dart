const bool isDeveloperBuild = bool.fromEnvironment(
  'OMOJI_DEVELOPER_BUILD',
  defaultValue: true,
);

const String omojiVersion = '1.2.6';
const String fullVersionUrl =
    'https://github.com/Aeroclipse-Proprietary-Limited/Omoji/releases';
