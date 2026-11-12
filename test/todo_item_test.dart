import 'package:flutter_test/flutter_test.dart';
import 'package:omoji/models/todo_item.dart';

void main() {
  group('TodoItem delayed status', () {
    final dueAt = DateTime(2026, 6, 1, 12);

    TodoItem makeTodo({DateTime? completedAt}) => TodoItem(
      id: 'event-1',
      title: 'Review',
      targetDateTime: dueAt,
      isCompleted: true,
      completedAt: completedAt,
    );

    test('is delayed only when completed after its due time', () {
      expect(
        makeTodo(completedAt: dueAt.add(const Duration(seconds: 1))).isDelayed,
        isTrue,
      );
      expect(makeTodo(completedAt: dueAt).isOnTimeCompleted, isTrue);
      expect(
        makeTodo(
          completedAt: dueAt.subtract(const Duration(seconds: 1)),
        ).isOnTimeCompleted,
        isTrue,
      );
      expect(
        makeTodo(
          completedAt: dueAt.add(const Duration(seconds: 1)),
        ).isOnTimeCompleted,
        isFalse,
      );
    });

    test(
      'older completed events without a completion time are not delayed',
      () {
        expect(makeTodo().isDelayed, isFalse);
      },
    );

    test('round-trips the completion time', () {
      final completedAt = dueAt.add(const Duration(days: 2));
      final restored = TodoItem.fromJson(
        makeTodo(completedAt: completedAt).toJson(),
      );

      expect(restored.completedAt, completedAt);
      expect(restored.isDelayed, isTrue);
    });
  });
}
