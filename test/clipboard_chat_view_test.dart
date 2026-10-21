import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoji/models/chat_message.dart';
import 'package:omoji/models/clipboard_item.dart';
import 'package:omoji/widgets/clipboard_chat_view.dart';
import 'package:omoji/widgets/clipboard_view.dart';

void main() {
  testWidgets('keeps chat temporary and disables unavailable model sending', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: ClipboardChatView(
              initialPrompt: 'Where is my clipboard match?',
              messages: const [],
              onBack: () {},
              onExport: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Your chat is temporary'), findsOneWidget);
    expect(
      find.textContaining('Quantum Network model integration'),
      findsOneWidget,
    );
    expect(find.text('Where is my clipboard match?'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.send_rounded),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.save_alt_rounded),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('reveals camera and recording options while hovering paperclip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: ClipboardChatView(
              initialPrompt: '',
              messages: const [],
              onBack: () {},
              onExport: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Attach file'), findsOneWidget);
    expect(find.byTooltip('Attach photo (not available yet)'), findsNothing);
    expect(find.byTooltip('Record audio (not available yet)'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.byTooltip('Attach file')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byTooltip('Attach photo (not available yet)'), findsOneWidget);
    expect(find.byTooltip('Record audio (not available yet)'), findsOneWidget);
    await mouse.removePointer();
  });

  testWidgets('shows message transcript and enables explicit export', (
    tester,
  ) async {
    var exportRequested = false;
    const messages = [
      ChatMessage(role: ChatRole.user, text: 'Hello'),
      ChatMessage(role: ChatRole.assistant, text: 'Hi there'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: ClipboardChatView(
              initialPrompt: '',
              messages: messages,
              onBack: () {},
              onExport: () => exportRequested = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Hi there'), findsOneWidget);
    await tester.tap(find.byTooltip('Export chat as text'));
    expect(exportRequested, isTrue);
  });

  testWidgets('offers chat when clipboard search has no matches', (
    tester,
  ) async {
    final editController = TextEditingController();
    final searchFocusNode = FocusNode();
    var chatRequested = false;
    addTearDown(editController.dispose);
    addTearDown(searchFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: ClipboardView(
              items: const <ClipboardItem>[],
              searchQuery: 'unmatched query',
              privateMode: false,
              editingIndex: null,
              editController: editController,
              searchFocusNode: searchFocusNode,
              onSelectText: (_) {},
              onSaveEdit: (_, _) {},
              onStartEdit: (_) {},
              onTogglePin: (_) {},
              onDeleteItem: (_) {},
              onTogglePrivateMode: (_) {},
              onClearHistory: () {},
              onStartChat: () => chatRequested = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('No matching items found'), findsOneWidget);
    await tester.tap(find.text('Chat with Omoji instead'));
    expect(chatRequested, isTrue);
  });
}
