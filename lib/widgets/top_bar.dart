import 'dart:io';

import 'package:flutter/material.dart';
import 'package:omoji/build_config.dart';
import 'package:omoji/services/update_check_service.dart';
import 'package:omoji/settings.dart';

class TopBar extends StatefulWidget {
  final FocusNode searchFocusNode;

  const TopBar({super.key, required this.searchFocusNode});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _spinController;
  late final Animation<double> _glowBlur;
  late final Animation<double> _spinTurns;
  bool _showVersion = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _glowBlur = Tween<double>(begin: 5, end: 22).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _spinTurns = CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeInOut,
    );
    UpdateCheckService.updateAvailable.addListener(_handleUpdateAvailability);
    if (UpdateCheckService.updateAvailable.value) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _handleUpdateAvailability() {
    if (!mounted) return;
    if (UpdateCheckService.updateAvailable.value) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
      _spinController.stop();
      _spinController.value = 0;
      _showVersion = false;
    }
    setState(() {});
  }

  void _toggleTitle() {
    setState(() => _showVersion = !_showVersion);
    _spinController.forward(from: 0);
  }

  @override
  void dispose() {
    UpdateCheckService.updateAvailable.removeListener(
      _handleUpdateAvailability,
    );
    _pulseController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hasUpdate = UpdateCheckService.updateAvailable.value;
    final displayedVersion = hasUpdate
        ? UpdateCheckService.latestVersion.value ?? omojiVersion
        : omojiVersion;
    final title = _showVersion ? 'v$displayedVersion' : 'Omoji';

    return Row(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) => Tooltip(
              message: hasUpdate
                  ? _showVersion
                        ? 'Update available — Revert to Omoji'
                        : 'Update available — Show version'
                  : _showVersion
                  ? 'Revert to Omoji'
                  : 'Show version',
              child: InkWell(
                onTap: _toggleTitle,
                onLongPress: hasUpdate ? () => _openReleases(context) : null,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 2,
                  ),
                  child: RotationTransition(
                    turns: _spinTurns,
                    child: Text(
                      title,
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
                                  blurRadius: _glowBlur.value,
                                ),
                                Shadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.55),
                                  blurRadius: _glowBlur.value * 1.5,
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

  Future<void> _openReleases(BuildContext context) async {
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
