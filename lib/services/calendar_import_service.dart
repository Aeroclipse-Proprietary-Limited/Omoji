import 'package:file_selector/file_selector.dart';
import 'package:omoji/models/todo_item.dart';

/// Imports calendar exports without coupling the calendar parsers to the UI.
/// Supports the iCalendar format used by Google, Yahoo, Outlook and Apple,
/// plus CSV exports with common title, description and start date columns.
class CalendarImportService {
  static Future<List<TodoItem>?> pickAndImport() async {
    const typeGroup = XTypeGroup(
      label: 'Calendar files',
      extensions: ['ics', 'ical', 'csv'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return null;
    final content = await file.readAsString();
    final extension = file.name.toLowerCase().split('.').last;
    return extension == 'csv' ? parseCsv(content) : parseIcalendar(content);
  }

  static List<TodoItem> parseIcalendar(String content) {
    final lines = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final unfolded = <String>[];
    for (final line in lines) {
      if ((line.startsWith(' ') || line.startsWith('\t')) &&
          unfolded.isNotEmpty) {
        unfolded[unfolded.length - 1] += line.substring(1);
      } else {
        unfolded.add(line);
      }
    }

    final events = <TodoItem>[];
    Map<String, String>? event;
    for (final line in unfolded) {
      if (line.toUpperCase() == 'BEGIN:VEVENT') {
        event = {};
      } else if (line.toUpperCase() == 'END:VEVENT' && event != null) {
        final title = _unescape(event['SUMMARY'] ?? '').trim();
        final start = _parseIcsDate(event['DTSTART'] ?? '');
        if (title.isNotEmpty && start != null) {
          events.add(
            TodoItem(
              id: 'calendar-${DateTime.now().microsecondsSinceEpoch}-${events.length}',
              title: title,
              description: _unescape(event['DESCRIPTION'] ?? '').trim(),
              targetDateTime: start,
            ),
          );
        }
        event = null;
      } else if (event != null) {
        final separator = line.indexOf(':');
        if (separator > 0) {
          final key = line
              .substring(0, separator)
              .split(';')
              .first
              .toUpperCase();
          if (key == 'SUMMARY' || key == 'DESCRIPTION' || key == 'DTSTART') {
            event[key] = line.substring(separator + 1);
          }
        }
      }
    }
    return events;
  }

  static List<TodoItem> parseCsv(String content) {
    final rows = _parseCsvRows(content);
    if (rows.length < 2) return [];
    final headers = rows.first.map(_normalizeHeader).toList();
    int? indexOf(Iterable<String> candidates) {
      for (final candidate in candidates) {
        final index = headers.indexOf(candidate);
        if (index >= 0) return index;
      }
      return null;
    }

    final titleIndex = indexOf([
      'subject',
      'title',
      'event',
      'event title',
      'summary',
      'task',
    ]);
    final startIndex = indexOf([
      'start date',
      'start',
      'start datetime',
      'start date time',
      'date',
      'datetime',
    ]);
    final timeIndex = indexOf(['start time', 'time']);
    final descriptionIndex = indexOf([
      'description',
      'details',
      'notes',
      'location',
    ]);
    if (titleIndex == null || startIndex == null) return [];

    final events = <TodoItem>[];
    for (final row in rows.skip(1)) {
      String value(int? index) =>
          index != null && index < row.length ? row[index].trim() : '';
      final title = value(titleIndex);
      if (title.isEmpty) continue;
      final rawDate = value(startIndex);
      final dateTime =
          DateTime.tryParse(rawDate) ?? _parseUsDate(rawDate, value(timeIndex));
      if (dateTime == null) continue;
      events.add(
        TodoItem(
          id: 'calendar-${DateTime.now().microsecondsSinceEpoch}-${events.length}',
          title: title,
          description: value(descriptionIndex),
          targetDateTime: dateTime,
        ),
      );
    }
    return events;
  }

  static DateTime? _parseIcsDate(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final dateOnly = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(raw);
    if (dateOnly != null) {
      return DateTime(
        int.parse(dateOnly[1]!),
        int.parse(dateOnly[2]!),
        int.parse(dateOnly[3]!),
      );
    }
    final dateTime = RegExp(
      r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})?(Z)?$',
    ).firstMatch(raw);
    if (dateTime == null) return DateTime.tryParse(raw);
    final parsed = DateTime.utc(
      int.parse(dateTime[1]!),
      int.parse(dateTime[2]!),
      int.parse(dateTime[3]!),
      int.parse(dateTime[4]!),
      int.parse(dateTime[5]!),
      int.tryParse(dateTime[6] ?? '0') ?? 0,
    );
    return dateTime[7] == 'Z'
        ? parsed.toLocal()
        : DateTime(
            parsed.year,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
            parsed.second,
          );
  }

  static DateTime? _parseUsDate(String date, String time) {
    final match = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$',
    ).firstMatch(date);
    if (match == null) return null;
    var year = int.parse(match[3]!);
    if (year < 100) year += year < 70 ? 2000 : 1900;
    var hour = 0;
    var minute = 0;
    final timeMatch = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$',
      caseSensitive: false,
    ).firstMatch(time);
    if (timeMatch != null) {
      hour = int.parse(timeMatch[1]!);
      minute = int.parse(timeMatch[2]!);
      final meridiem = timeMatch[3]?.toUpperCase();
      if (meridiem == 'PM' && hour < 12) hour += 12;
      if (meridiem == 'AM' && hour == 12) hour = 0;
    }
    return DateTime(
      year,
      int.parse(match[1]!),
      int.parse(match[2]!),
      hour,
      minute,
    );
  }

  static String _unescape(String value) => value
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\\', r'\');

  static String _normalizeHeader(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  static List<List<String>> _parseCsvRows(String content) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < content.length; i++) {
      final char = content[i];
      if (char == '"') {
        if (quoted && i + 1 < content.length && content[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        row.add(field.toString());
        field.clear();
      } else if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
          i++;
        }
        row.add(field.toString());
        field.clear();
        if (row.any((cell) => cell.trim().isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        field.write(char);
      }
    }
    row.add(field.toString());
    if (row.any((cell) => cell.trim().isNotEmpty)) rows.add(row);
    return rows;
  }
}
