import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoji/widgets/full_version_prompt.dart';

void main() {
  testWidgets('prompt distinguishes accidental taps from full-version intent', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showFullVersionPrompt(
                context,
                feature: 'Clock tools',
              );
            },
            child: const Text('Open feature'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open feature'));
    await tester.pumpAndSettle();

    expect(find.text('Accidental tap'), findsOneWidget);
    expect(find.text('View full version'), findsOneWidget);
    expect(find.textContaining('Donations are optional gifts'), findsOneWidget);

    await tester.tap(find.text('Accidental tap'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('Open feature'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View full version'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
