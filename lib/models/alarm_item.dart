// lib/models/alarm_item.dart

class AlarmItem {
  final String id;
  String time; // Format "HH:mm" e.g. "03:50", "21:29"
  String label;
  bool isEnabled;
  List<int> repeatDays; // 1 = Mon, 2 = Tue, ..., 7 = Sun. Empty list = One time
  String? lastFiredDate; // YYYY-MM-DD to avoid re-triggering within the same minute
  int autoSilenceMinutes; // Default 5 minutes

  AlarmItem({
    required this.id,
    required this.time,
    this.label = 'Alarm',
    this.isEnabled = true,
    List<int>? repeatDays,
    this.lastFiredDate,
    int? autoSilenceMinutes,
  })  : repeatDays = repeatDays ?? [],
        autoSilenceMinutes = autoSilenceMinutes ?? 5;

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time,
        'label': label,
        'isEnabled': isEnabled,
        'repeatDays': repeatDays,
        'lastFiredDate': lastFiredDate,
        'autoSilenceMinutes': autoSilenceMinutes,
      };

  factory AlarmItem.fromJson(Map<String, dynamic> json) {
    return AlarmItem(
      id: (json['id'] as String?) ?? DateTime.now().millisecondsSinceEpoch.toString(),
      time: (json['time'] as String?) ?? '08:00',
      label: (json['label'] as String?) ?? 'Alarm',
      isEnabled: (json['isEnabled'] as bool?) ?? true,
      repeatDays: (json['repeatDays'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      lastFiredDate: json['lastFiredDate'] as String?,
      autoSilenceMinutes: (json['autoSilenceMinutes'] as int?) ?? 5,
    );
  }

  String get repeatSummary {
    if (repeatDays.isEmpty) return 'One-time';
    if (repeatDays.length == 7) return 'Every Day';
    if (repeatDays.length == 5 &&
        repeatDays.contains(1) &&
        repeatDays.contains(2) &&
        repeatDays.contains(3) &&
        repeatDays.contains(4) &&
        repeatDays.contains(5)) {
      return 'Weekdays';
    }
    if (repeatDays.length == 2 && repeatDays.contains(6) && repeatDays.contains(7)) {
      return 'Weekends';
    }
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return repeatDays.map((d) => dayNames[d - 1]).join(', ');
  }
}
