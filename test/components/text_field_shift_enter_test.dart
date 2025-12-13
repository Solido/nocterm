import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/keyboard/keyboard_parser.dart';
import 'package:test/test.dart';

void main() {
  group('Shift+Enter Detection', () {
    group('Keyboard Parser', () {
      late KeyboardParser parser;

      setUp(() {
        parser = KeyboardParser();
      });

      test('parses CSI u sequence for Shift+Enter (ESC [ 13 ; 2 u)', () {
        // ESC [ 1 3 ; 2 u - Kitty keyboard protocol for Shift+Enter
        // codepoint=13 (Enter), modifier=2 (Shift)
        final bytes = [0x1B, 0x5B, 0x31, 0x33, 0x3B, 0x32, 0x75];
        final event = parser.parseBytes(bytes);

        expect(event, isNotNull);
        expect(event!.logicalKey, equals(LogicalKey.enter));
        expect(event.isShiftPressed, isTrue);
        expect(event.isControlPressed, isFalse);
        expect(event.isAltPressed, isFalse);
        expect(event.character, equals('\n'));
      });

      test('parses CSI u sequence for plain Enter (ESC [ 13 u)', () {
        // ESC [ 1 3 u - Kitty keyboard protocol for plain Enter
        final bytes = [0x1B, 0x5B, 0x31, 0x33, 0x75];
        final event = parser.parseBytes(bytes);

        expect(event, isNotNull);
        expect(event!.logicalKey, equals(LogicalKey.enter));
        expect(event.isShiftPressed, isFalse);
        expect(event.character, equals('\n'));
      });

      test('parses CSI u sequence for Ctrl+Enter (ESC [ 13 ; 5 u)', () {
        // ESC [ 1 3 ; 5 u - Kitty keyboard protocol for Ctrl+Enter
        // codepoint=13 (Enter), modifier=5 (Ctrl)
        final bytes = [0x1B, 0x5B, 0x31, 0x33, 0x3B, 0x35, 0x75];
        final event = parser.parseBytes(bytes);

        expect(event, isNotNull);
        expect(event!.logicalKey, equals(LogicalKey.enter));
        expect(event.isControlPressed, isTrue);
        expect(event.isShiftPressed, isFalse);
      });

      test('parses CSI u sequence for Ctrl+Shift+Enter (ESC [ 13 ; 6 u)', () {
        // ESC [ 1 3 ; 6 u - Kitty keyboard protocol for Ctrl+Shift+Enter
        // codepoint=13 (Enter), modifier=6 (Ctrl+Shift)
        final bytes = [0x1B, 0x5B, 0x31, 0x33, 0x3B, 0x36, 0x75];
        final event = parser.parseBytes(bytes);

        expect(event, isNotNull);
        expect(event!.logicalKey, equals(LogicalKey.enter));
        expect(event.isControlPressed, isTrue);
        expect(event.isShiftPressed, isTrue);
      });

      test('parses ESC+newline as Shift+Enter fallback', () {
        // ESC followed by 0x0A (newline) - Shift+Enter fallback
        final bytes = [0x1B, 0x0A];
        final event = parser.parseBytes(bytes);

        expect(event, isNotNull);
        expect(event!.logicalKey, equals(LogicalKey.enter));
        expect(event.isShiftPressed, isTrue);
        expect(event.isControlPressed, isFalse);
        expect(event.character, equals('\n'));
      });

      test('parses plain Enter (0x0D) without shift', () {
        final bytes = [0x0D];
        final event = parser.parseBytes(bytes);

        expect(event, isNotNull);
        expect(event!.logicalKey, equals(LogicalKey.enter));
        expect(event.isShiftPressed, isFalse);
      });

      test('parses plain Enter (0x0A) without shift', () {
        final bytes = [0x0A];
        final event = parser.parseBytes(bytes);

        expect(event, isNotNull);
        expect(event!.logicalKey, equals(LogicalKey.enter));
        expect(event.isShiftPressed, isFalse);
      });

      test('parses CSI u sequence for Tab with modifiers', () {
        // ESC [ 9 ; 2 u - Kitty keyboard protocol for Shift+Tab
        final bytes = [0x1B, 0x5B, 0x39, 0x3B, 0x32, 0x75];
        final event = parser.parseBytes(bytes);

        expect(event, isNotNull);
        expect(event!.logicalKey, equals(LogicalKey.tab));
        expect(event.isShiftPressed, isTrue);
      });

      test('parses CSI u sequence for Escape', () {
        // ESC [ 27 u - Kitty keyboard protocol for Escape
        final bytes = [0x1B, 0x5B, 0x32, 0x37, 0x75];
        final event = parser.parseBytes(bytes);

        expect(event, isNotNull);
        expect(event!.logicalKey, equals(LogicalKey.escape));
      });

      test('parses CSI u sequence for printable character with Shift', () {
        // ESC [ 65 ; 2 u - Kitty keyboard protocol for Shift+A (codepoint 65)
        final bytes = [0x1B, 0x5B, 0x36, 0x35, 0x3B, 0x32, 0x75];
        final event = parser.parseBytes(bytes);

        expect(event, isNotNull);
        expect(event!.character, equals('A'));
        expect(event.isShiftPressed, isTrue);
      });
    });

    group('TextField Integration', () {
      test('Shift+Enter inserts newline in multi-line field', () async {
        await testNocterm(
          'shift enter multiline',
          (tester) async {
            final controller = TextEditingController(text: 'Line 1');
            bool submitted = false;

            await tester.pumpComponent(
              TextField(
                controller: controller,
                maxLines: 5,
                focused: true,
                onSubmitted: (_) => submitted = true,
                width: 30,
                decoration: const InputDecoration(
                  border: BoxBorder(),
                ),
              ),
            );

            // Initial cursor at end
            expect(controller.text, equals('Line 1'));
            expect(controller.selection.extentOffset, equals(6));

            // Send Shift+Enter
            await tester.sendKeyEvent(KeyboardEvent(
              logicalKey: LogicalKey.enter,
              character: '\n',
              modifiers: const ModifierKeys(shift: true),
            ));

            // Should insert newline, not submit
            expect(controller.text, equals('Line 1\n'));
            expect(submitted, isFalse);
            expect(controller.selection.extentOffset, equals(7));
          },
        );
      });

      test('Shift+Enter is consumed but does nothing in single-line field',
          () async {
        await testNocterm(
          'shift enter single line',
          (tester) async {
            final controller = TextEditingController(text: 'Single line');
            bool submitted = false;

            await tester.pumpComponent(
              TextField(
                controller: controller,
                maxLines: 1,
                focused: true,
                onSubmitted: (_) => submitted = true,
                width: 30,
                decoration: const InputDecoration(
                  border: BoxBorder(),
                ),
              ),
            );

            // Send Shift+Enter
            await tester.sendKeyEvent(KeyboardEvent(
              logicalKey: LogicalKey.enter,
              character: '\n',
              modifiers: const ModifierKeys(shift: true),
            ));

            // Should not submit and not insert newline (just consumed)
            // This prevents accidental form submission when user intends newline
            expect(controller.text, equals('Single line'));
            expect(submitted, isFalse);
          },
        );
      });

      test('Regular Enter submits multi-line field', () async {
        await testNocterm(
          'enter multiline submits',
          (tester) async {
            final controller = TextEditingController(text: 'Line 1');
            bool submitted = false;

            await tester.pumpComponent(
              TextField(
                controller: controller,
                maxLines: 5,
                focused: true,
                onSubmitted: (_) => submitted = true,
                width: 30,
                decoration: const InputDecoration(
                  border: BoxBorder(),
                ),
              ),
            );

            // Send plain Enter
            await tester.sendKeyEvent(KeyboardEvent(
              logicalKey: LogicalKey.enter,
              modifiers: const ModifierKeys(),
            ));

            // Should submit
            expect(controller.text, equals('Line 1'));
            expect(submitted, isTrue);
          },
        );
      });

      test('Multiple Shift+Enter presses create multiple lines', () async {
        await testNocterm(
          'multiple shift enter',
          (tester) async {
            final controller = TextEditingController(text: 'First');

            await tester.pumpComponent(
              TextField(
                controller: controller,
                maxLines: 10,
                focused: true,
                width: 30,
                decoration: const InputDecoration(
                  border: BoxBorder(),
                ),
              ),
            );

            // Send Shift+Enter twice
            await tester.sendKeyEvent(KeyboardEvent(
              logicalKey: LogicalKey.enter,
              character: '\n',
              modifiers: const ModifierKeys(shift: true),
            ));

            await tester.sendKeyEvent(KeyboardEvent(
              logicalKey: LogicalKey.enter,
              character: '\n',
              modifiers: const ModifierKeys(shift: true),
            ));

            // Should have two newlines
            expect(controller.text, equals('First\n\n'));
          },
        );
      });

      test('Shift+Enter respects maxLines limit', () async {
        await testNocterm(
          'shift enter max lines',
          (tester) async {
            // Start with 2 lines, maxLines is 3
            final controller = TextEditingController(text: 'Line 1\nLine 2');

            await tester.pumpComponent(
              TextField(
                controller: controller,
                maxLines: 3,
                focused: true,
                width: 30,
                decoration: const InputDecoration(
                  border: BoxBorder(),
                ),
              ),
            );

            // Current text has 2 lines, maxLines is 3 so one more should work
            await tester.sendKeyEvent(KeyboardEvent(
              logicalKey: LogicalKey.enter,
              character: '\n',
              modifiers: const ModifierKeys(shift: true),
            ));

            expect(controller.text, equals('Line 1\nLine 2\n'));

            // Now we have 3 lines, adding another should be blocked
            await tester.sendKeyEvent(KeyboardEvent(
              logicalKey: LogicalKey.enter,
              character: '\n',
              modifiers: const ModifierKeys(shift: true),
            ));

            // Should still have 3 lines only
            expect(controller.text, equals('Line 1\nLine 2\n'));
          },
        );
      });
    });
  });
}
