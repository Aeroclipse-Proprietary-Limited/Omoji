// lib/widgets/tab_switcher.dart

import 'package:flutter/material.dart';

class TabSwitcher extends StatelessWidget {
  final String selectedTab;
  final ValueChanged<String> onTabChanged;
  final FocusNode searchFocusNode;

  const TabSwitcher({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    required this.searchFocusNode,
  });

  Widget _buildTabButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final activeBg = Colors.teal;
    final inactiveBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Expanded(
      child: Focus(
        canRequestFocus: false,
        child: InkWell(
          onTap: () {
            onTap();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              searchFocusNode.requestFocus();
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: isActive ? activeBg : inactiveBg,
              border: Border.all(color: isActive ? Colors.teal : borderColor),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildTabButton(
          context: context,
          label: 'Clipboard',
          icon: Icons.assignment_outlined,
          isActive: selectedTab == 'clipboard',
          onTap: () => onTabChanged('clipboard'),
        ),
        const SizedBox(width: 12),
        _buildTabButton(
          context: context,
          label: 'Emojis',
          icon: Icons.emoji_emotions_outlined,
          isActive: selectedTab == 'emojis',
          onTap: () => onTabChanged('emojis'),
        ),
      ],
    );
  }
}
