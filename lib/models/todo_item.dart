// lib/models/todo_item.dart

class TodoItem {
  final String id;
  String title;
  String description;
  DateTime targetDateTime;
  bool isCompleted;
  final DateTime createdAt;
  bool hasNotified;

  TodoItem({
    required this.id,
    required this.title,
    this.description = '',
    required this.targetDateTime,
    this.isCompleted = false,
    DateTime? createdAt,
    this.hasNotified = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'targetDateTime': targetDateTime.toIso8601String(),
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
        'hasNotified': hasNotified,
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: (json['id'] as String?) ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: (json['title'] as String?) ?? 'Task',
      description: (json['description'] as String?) ?? '',
      targetDateTime: json['targetDateTime'] != null
          ? DateTime.parse(json['targetDateTime'] as String)
          : DateTime.now().add(const Duration(days: 7)),
      isCompleted: (json['isCompleted'] as bool?) ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      hasNotified: (json['hasNotified'] as bool?) ?? false,
    );
  }

  String get timeRemainingSummary {
    if (isCompleted) return 'Completed';
    final now = DateTime.now();
    final difference = targetDateTime.difference(now);

    if (difference.isNegative) {
      final daysPast = difference.inDays.abs();
      if (daysPast == 0) return 'Overdue today';
      return 'Overdue by ${daysPast}d';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;

    if (days == 0) {
      if (hours == 0) {
        final mins = difference.inMinutes % 60;
        return 'Due in ${mins}m';
      }
      return 'Due in ${hours}h';
    } else if (days == 1) {
      return 'Tomorrow';
    } else if (days < 7) {
      return 'In $days days';
    } else if (days < 14) {
      return 'In 1 week';
    } else if (days < 30) {
      final weeks = (days / 7).round();
      return 'In $weeks weeks';
    } else {
      final months = (days / 30).round();
      return 'In $months month${months > 1 ? 's' : ''}';
    }
  }

  String get formattedTargetDate {
    final year = targetDateTime.year;
    final month = targetDateTime.month.toString().padLeft(2, '0');
    final day = targetDateTime.day.toString().padLeft(2, '0');
    final hour = targetDateTime.hour.toString().padLeft(2, '0');
    final minute = targetDateTime.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
