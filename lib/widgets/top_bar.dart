// lib/widgets/top_bar.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:omoji/build_config.dart';
import 'package:omoji/services/update_check_service.dart';
import 'package:omoji/settings.dart';

class TopBar extends StatelessWidget {
  final FocusNode searchFocusNode;

  const TopBar({super.key, required this.searchFocusNode});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Row(
      children: [
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: UpdateCheckService.updateAvailable,
            builder: (context, hasUpdate, _) => Tooltip(
              message: hasUpdate
                  ? 'Update available — open GitHub Releases'
                  : 'Omoji',
              child: InkWell(
                onTap: hasUpdate ? () => _showUpdateDialog(context) : null,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 2,
                  ),
                  child: Text(
                    'Omoji',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: hasUpdate
                          ? [
                              Shadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.85),
                                blurRadius: 14,
                              ),
                              Shadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.55),
                                blurRadius: 24,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Focus(
          canRequestFocus: false,
          child: IconButton(
            icon: const Icon(Icons.settings_outlined),
            color: textColor.withValues(alpha: 0.7),
            splashRadius: 20,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showUpdateDialog(BuildContext context) async {
    final version = UpdateCheckService.latestVersion.value;
    final sources = UpdateCheckService.updateSources.value.toList()..sort();
    final shouldOpenReleases = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Omoji update available'),
        content: Text(
          'A newer version${version == null ? '' : ' ($version)'} is available'
          '${sources.isEmpty ? '' : ' from ${sources.join(' and ')}'}. '
          'This check sends only a request for public release information; '
          'it does not send app usage or clipboard data. GitHub and Snap Store '
          'still receive ordinary connection metadata, such as your IP address.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('View GitHub Releases'),
          ),
        ],
      ),
    );
    if (shouldOpenReleases != true || !context.mounted) return;

    final command = Platform.isLinux
        ? ('xdg-open', [fullVersionUrl])
        : Platform.isMacOS
        ? ('open', [fullVersionUrl])
        : Platform.isWindows
        ? ('rundll32', ['url.dll,FileProtocolHandler', fullVersionUrl])
        : throw UnsupportedError(
            'GitHub Releases are not supported on this platform.',
          );
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await Process.run(command.$1, command.$2);
      if (result.exitCode != 0 && context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not open GitHub Releases: ${result.stderr}'),
          ),
        );
      }
    } on ProcessException catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not open GitHub Releases: $error')),
        );
      }
    }
  }
}
