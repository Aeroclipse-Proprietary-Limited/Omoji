import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoji/widgets/tab_switcher.dart';

void main() {
  testWidgets('tab selection animates when animations are enabled', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    String selectedTab = 'clipboard';

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: TabSwitcher(
              selectedTab: selectedTab,
              animationsEnabled: true,
              onTabChanged: (tab) => setState(() => selectedTab = tab),
              searchFocusNode: focusNode,
            ),
          ),
        ),
      ),
    );

    Color emojiTabColor() {
      final finder = find.ancestor(
        of: find.text('Emojis'),
        matching: find.byType(DecoratedBox),
      );
      return (tester.widget<DecoratedBox>(finder.first).decoration
              as BoxDecoration)
          .color!;
    }

    final initialColor = emojiTabColor();
    final activeColor = Theme.of(tester.element(find.byType(TabSwitcher)))
        .colorScheme
        .primary;

    await tester.tap(find.text('Emojis'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));

    final transitionColor = emojiTabColor();
    expect(transitionColor, isNot(initialColor));
    expect(transitionColor, isNot(activeColor));

    await tester.pumpAndSettle();
    expect(emojiTabColor(), activeColor);
  });

  testWidgets(
    'tab selection changes immediately when animations are disabled',
    (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      String selectedTab = 'clipboard';

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: TabSwitcher(
                selectedTab: selectedTab,
                animationsEnabled: false,
                onTabChanged: (tab) => setState(() => selectedTab = tab),
                searchFocusNode: focusNode,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Emojis'));
      await tester.pump();

      final finder = find.ancestor(
        of: find.text('Emojis'),
        matching: find.byType(DecoratedBox),
      );
      final emojiTabColor =
          (tester.widget<DecoratedBox>(finder.first).decoration
                  as BoxDecoration)
              .color;
      final activeColor = Theme.of(tester.element(find.byType(TabSwitcher)))
          .colorScheme
          .primary;

      expect(emojiTabColor, activeColor);
    },
  );
}
