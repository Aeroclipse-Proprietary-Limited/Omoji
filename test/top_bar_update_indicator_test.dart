import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoji/build_config.dart';
import 'package:omoji/services/update_check_service.dart';
import 'package:omoji/widgets/top_bar.dart';

void main() {
  testWidgets('title toggles the installed version when there is no update', (
    tester,
  ) async {
    UpdateCheckService.latestVersion.value = null;
    UpdateCheckService.updateAvailable.value = false;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 400, child: TopBar(searchFocusNode: focusNode)),
        ),
      ),
    );

    expect(find.text('Omoji'), findsOneWidget);
    await tester.tap(find.text('Omoji'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('v$omojiVersion'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('v$omojiVersion')).style?.shadows,
      isNull,
    );

    await tester.tap(find.text('v$omojiVersion'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Omoji'), findsOneWidget);
  });

  testWidgets('update title toggles the available version and keeps glowing', (
    tester,
  ) async {
    UpdateCheckService.latestVersion.value = '1.2.7';
    UpdateCheckService.updateAvailable.value = true;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    addTearDown(() {
      UpdateCheckService.updateAvailable.value = false;
      UpdateCheckService.latestVersion.value = null;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 400, child: TopBar(searchFocusNode: focusNode)),
        ),
      ),
    );

    expect(find.text('Omoji'), findsOneWidget);
    await tester.tap(find.text('Omoji'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('v1.2.7'), findsOneWidget);
    expect(
      tester
          .widget<RotationTransition>(
            find.descendant(
              of: find.byType(TopBar),
              matching: find.byType(RotationTransition),
            ),
          )
          .turns
          .status,
      AnimationStatus.forward,
    );

    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('v1.2.7'), findsOneWidget);
    expect(
      tester
          .widget<RotationTransition>(
            find.descendant(
              of: find.byType(TopBar),
              matching: find.byType(RotationTransition),
            ),
          )
          .turns
          .value,
      closeTo(1, 0.001),
    );
    expect(UpdateCheckService.updateAvailable.value, isTrue);

    await tester.tap(find.text('v1.2.7'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Omoji'), findsOneWidget);
    expect(UpdateCheckService.updateAvailable.value, isTrue);
  });
}
