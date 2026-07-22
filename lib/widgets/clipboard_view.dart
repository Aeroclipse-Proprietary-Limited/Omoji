// lib/widgets/clipboard_view.dart

import 'package:flutter/material.dart';
import 'package:omoji/models/clipboard_item.dart';

class ClipboardView extends StatelessWidget {
  final List<ClipboardItem> items;
  final String searchQuery;
  final bool privateMode;
  final int? editingIndex;
  final TextEditingController editController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSelectText;
  final Function(int, String) onSaveEdit;
  final ValueChanged<int> onStartEdit;
  final ValueChanged<ClipboardItem> onTogglePin;
  final ValueChanged<ClipboardItem> onDeleteItem;
  final ValueChanged<bool> onTogglePrivateMode;
  final VoidCallback onClearHistory;

  const ClipboardView({
    super.key,
    required this.items,
    required this.searchQuery,
    required this.privateMode,
    required this.editingIndex,
    required this.editController,
    required this.searchFocusNode,
    required this.onSelectText,
    required this.onSaveEdit,
    required this.onStartEdit,
    required this.onTogglePin,
    required this.onDeleteItem,
    required this.onTogglePrivateMode,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    return Column(
      children: [
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    searchQuery.isEmpty
                        ? 'Clipboard history is empty'
                        : 'No matching items found',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isEditing = editingIndex == index;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border.all(color: cardBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.isPinned ? Icons.push_pin : Icons.circle,
                              size: item.isPinned ? 12 : 8,
                              color: item.isPinned
                                  ? Colors.teal
                                  : textColor.withValues(alpha: 0.3),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: isEditing
                                  ? TextField(
                                      controller: editController,
                                      autofocus: true,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 13,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onSubmitted: (val) => onSaveEdit(index, val),
                                    )
                                  : InkWell(
                                      onTap: () => onSelectText(item.text),
                                      child: Text(
                                        item.text.replaceAll('\n', ' '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            if (isEditing)
                              IconButton(
                                icon: const Icon(Icons.check_rounded, size: 16),
                                color: Colors.teal,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () =>
                                    onSaveEdit(index, editController.text),
                              )
                            else ...[
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                color: textColor.withValues(alpha: 0.6),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () => onStartEdit(index),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(
                                  item.isPinned
                                      ? Icons.push_pin
                                      : Icons.push_pin_outlined,
                                  size: 16,
                                ),
                                color: item.isPinned
                                    ? Colors.teal
                                    : textColor.withValues(alpha: 0.6),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () => onTogglePin(item),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                color: textColor.withValues(alpha: 0.6),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () => onSelectText(item.text),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                ),
                                color: Colors.redAccent.withValues(alpha: 0.7),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () => onDeleteItem(item),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        Divider(color: isDark ? Colors.white10 : Colors.black12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            privateMode ? Icons.security : Icons.security_outlined,
            color: privateMode
                ? Colors.teal
                : textColor.withValues(alpha: 0.7),
            size: 20,
          ),
          title: Text(
            'Private mode',
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Switch(
            value: privateMode,
            activeTrackColor: Colors.teal.withValues(alpha: 0.5),
            activeThumbColor: Colors.teal,
            onChanged: onTogglePrivateMode,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.delete_sweep_outlined,
            color: Colors.redAccent.withValues(alpha: 0.8),
            size: 20,
          ),
          title: Text(
            'Clear history',
            style: TextStyle(
              color: Colors.redAccent.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: onClearHistory,
        ),
      ],
    );
  }
}
