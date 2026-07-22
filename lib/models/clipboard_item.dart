// lib/models/clipboard_item.dart

class ClipboardItem {
  String text;
  bool isPinned;
  int timestamp;

  ClipboardItem({
    required this.text,
    this.isPinned = false,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'text': text,
        'isPinned': isPinned,
        'timestamp': timestamp,
      };

  factory ClipboardItem.fromJson(Map<String, dynamic> json) {
    return ClipboardItem(
      text: (json['text'] as String?) ?? '',
      isPinned: (json['isPinned'] as bool?) ?? false,
      timestamp: json['timestamp'] as int?,
    );
  }
}
