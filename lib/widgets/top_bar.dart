// lib/widgets/top_bar.dart

import 'package:flutter/material.dart';
import 'package:omoji/settings.dart';
import 'package:window_manager/window_manager.dart';

class TopBar extends StatelessWidget {
  final FocusNode searchFocusNode;

  const TopBar({
    super.key,
    required this.searchFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Omoji',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
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
        Focus(
          canRequestFocus: false,
          child: IconButton(
            icon: const Icon(Icons.close_rounded),
            color: textColor.withValues(alpha: 0.7),
            splashRadius: 20,
            onPressed: () async => await windowManager.minimize(),
          ),
        ),
      ],
    );
  }
}
