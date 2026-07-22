// lib/widgets/emoji_view.dart

import 'package:flutter/material.dart';
import 'package:omoji/data/emoji_map.dart';

class EmojiView extends StatelessWidget {
  final String searchQuery;
  final List<String> recentEmojis;
  final ValueChanged<String> onSelectEmoji;

  const EmojiView({
    super.key,
    required this.searchQuery,
    required this.recentEmojis,
    required this.onSelectEmoji,
  });

  Widget _buildRecentEmojisSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Icon(Icons.history,
                  size: 16, color: textColor.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                'Recently Used',
                style: TextStyle(
                  fontSize: 13,
                  color: textColor.withValues(alpha: 0.4),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 55,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: recentEmojis.length,
          itemBuilder: (context, index) {
            final emoji = recentEmojis[index];
            return Focus(
              canRequestFocus: false,
              child: InkWell(
                onTap: () => onSelectEmoji(emoji),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.18),
                    border:
                        Border.all(color: Colors.teal.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    emoji,
                    style: const TextStyle(
                      fontSize: 24,
                      fontFamilyFallback: ['NotoColorEmoji'],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Divider(color: isDark ? Colors.white10 : Colors.black12),
        ),
      ],
    );
  }

  List<Widget> _buildEmojiSections(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    List<Widget> sections = [];

    fullEmojiData.forEach((category, emojis) {
      final filteredEmojis = emojis.where((e) {
        return e['name']!.contains(searchQuery) ||
            e['char']!.contains(searchQuery);
      }).toList();

      if (filteredEmojis.isNotEmpty) {
        sections.add(
          Padding(
            padding: const EdgeInsets.only(top: 14.0, bottom: 8.0),
            child: Text(
              category,
              style: TextStyle(
                fontSize: 13,
                color: textColor.withValues(alpha: 0.4),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );

        sections.add(
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 55,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: filteredEmojis.length,
            itemBuilder: (context, index) {
              final emoji = filteredEmojis[index];
              return Focus(
                canRequestFocus: false,
                child: InkWell(
                  onTap: () => onSelectEmoji(emoji['char']!),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: Border.all(color: cardBorder),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emoji['char']!,
                      style: const TextStyle(
                        fontSize: 24,
                        fontFamilyFallback: ['NotoColorEmoji'],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }
    });

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (searchQuery.isEmpty && recentEmojis.isNotEmpty)
          _buildRecentEmojisSection(context),
        ..._buildEmojiSections(context),
      ],
    );
  }
}
