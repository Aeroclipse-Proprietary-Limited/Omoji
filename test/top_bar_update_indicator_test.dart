import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoji/services/update_check_service.dart';
import 'package:omoji/widgets/top_bar.dart';

void main() {
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
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('v1.2.7'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('v1.2.7'), findsOneWidget);
    expect(UpdateCheckService.updateAvailable.value, isTrue);

    await tester.tap(find.text('v1.2.7'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Omoji'), findsOneWidget);
    expect(UpdateCheckService.updateAvailable.value, isTrue);
  });
}
