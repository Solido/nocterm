import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart' hide isEmpty;

void main() {
  group('TextField undo/redo', () {
    test('type text, undo reverts to empty', () async {
      await testNocterm(
        'undo basic',
        (tester) async {
          final controller = TextEditingController(text: '');

          await tester.pumpComponent(
            TextField(
              controller: controller,
              focused: true,
              decoration: InputDecoration(
                border: BoxBorder.all(),
              ),
            ),
          );

          // Type "hello"
          await tester.enterText('hello');
          await tester.pump();
          expect(controller.text, equals('hello'));

          // Undo with Ctrl+Z
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.keyZ,
            modifiers: const ModifierKeys(ctrl: true),
          ));
          await tester.pump();

          // Should be empty
          expect(controller.text, equals(''));
        },
      );
    });

    test('type, undo, redo restores text', () async {
      await testNocterm(
        'undo redo',
        (tester) async {
          final controller = TextEditingController(text: '');

          await tester.pumpComponent(
            TextField(
              controller: controller,
              focused: true,
              decoration: InputDecoration(
                border: BoxBorder.all(),
              ),
            ),
          );

          // Type "hello"
          await tester.enterText('hello');
          await tester.pump();

          // Undo
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.keyZ,
            modifiers: const ModifierKeys(ctrl: true),
          ));
          await tester.pump();
          expect(controller.text, equals(''));

          // Redo with Ctrl+Y
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.keyY,
            modifiers: const ModifierKeys(ctrl: true),
          ));
          await tester.pump();
          expect(controller.text, equals('hello'));
        },
      );
    });

    test('redo with Ctrl+Shift+Z', () async {
      await testNocterm(
        'redo with shift',
        (tester) async {
          final controller = TextEditingController(text: '');

          await tester.pumpComponent(
            TextField(
              controller: controller,
              focused: true,
              decoration: InputDecoration(
                border: BoxBorder.all(),
              ),
            ),
          );

          // Type "hello"
          await tester.enterText('hello');
          await tester.pump();

          // Undo
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.keyZ,
            modifiers: const ModifierKeys(ctrl: true),
          ));
          await tester.pump();
          expect(controller.text, equals(''));

          // Redo with Ctrl+Shift+Z
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.keyZ,
            modifiers: const ModifierKeys(ctrl: true, shift: true),
          ));
          await tester.pump();
          expect(controller.text, equals('hello'));
        },
      );
    });

    test('redo stack is cleared on new edit', () async {
      await testNocterm(
        'redo stack cleared',
        (tester) async {
          final controller = TextEditingController(text: '');

          await tester.pumpComponent(
            TextField(
              controller: controller,
              focused: true,
              decoration: InputDecoration(
                border: BoxBorder.all(),
              ),
            ),
          );

          // Type "hello"
          await tester.enterText('hello');
          await tester.pump();

          // Undo
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.keyZ,
            modifiers: const ModifierKeys(ctrl: true),
          ));
          await tester.pump();
          expect(controller.text, equals(''));

          // Type something new
          await tester.enterText('world');
          await tester.pump();

          // Try to redo - should do nothing since we made a new edit
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.keyY,
            modifiers: const ModifierKeys(ctrl: true),
          ));
          await tester.pump();

          // Should still be "world", not "hello"
          expect(controller.text, equals('world'));
        },
      );
    });

    test('multiple undos work correctly', () async {
      await testNocterm(
        'multiple undos',
        (tester) async {
          final controller = TextEditingController(text: '');

          await tester.pumpComponent(
            TextField(
              controller: controller,
              focused: true,
              decoration: InputDecoration(
                border: BoxBorder.all(),
              ),
            ),
          );

          // Type "hello" (one batch)
          await tester.enterText('hello');
          await tester.pump();

          // Type space (word boundary - triggers new batch)
          await tester.enterText(' ');
          await tester.pump();

          // Type "world" (second batch)
          await tester.enterText('world');
          await tester.pump();
          expect(controller.text, equals('hello world'));

          // Undo should remove "world"
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.keyZ,
            modifiers: const ModifierKeys(ctrl: true),
          ));
          await tester.pump();
          expect(controller.text, equals('hello '));

          // Undo should remove " "
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.keyZ,
            modifiers: const ModifierKeys(ctrl: true),
          ));
          await tester.pump();
          expect(controller.text, equals('hello'));

          // Undo should remove "hello"
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.keyZ,
            modifiers: const ModifierKeys(ctrl: true),
          ));
          await tester.pump();
          expect(controller.text, equals(''));
        },
      );
    });

    test('delete operations are individual undo units', () async {
      await testNocterm(
        'delete undo',
        (tester) async {
          final controller = TextEditingController(text: 'hello');

          await tester.pumpComponent(
            TextField(
              controller: controller,
              focused: true,
              decoration: InputDecoration(
                border: BoxBorder.all(),
              ),
            ),
          );

          // Cursor at end, delete one character with backspace
          await tester.sendKey(LogicalKey.backspace);
          await tester.pump();
          expect(controller.text, equals('hell'));

          // Delete another character
          await tester.sendKey(LogicalKey.backspace);
          await tester.pump();
          expect(controller.text, equals('hel'));

          // Undo should restore one character
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.keyZ,
            modifiers: const ModifierKeys(ctrl: true),
          ));
          await tester.pump();
          expect(controller.text, equals('hell'));

          // Undo should restore another character
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.keyZ,
            modifiers: const ModifierKeys(ctrl: true),
          ));
          await tester.pump();
          expect(controller.text, equals('hello'));
        },
      );
    });
  });

  group('TextField selection keybindings', () {
    test('Shift+Home selects to line start', () async {
      await testNocterm(
        'shift home',
        (tester) async {
          final controller = TextEditingController(text: 'Hello World');
          controller.selection = TextSelection.collapsed(offset: 6);

          await tester.pumpComponent(
            TextField(
              controller: controller,
              focused: true,
              decoration: InputDecoration(
                border: BoxBorder.all(),
              ),
            ),
          );

          // Shift+Home
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.home,
            modifiers: const ModifierKeys(shift: true),
          ));
          await tester.pump();

          // Selection should extend from 6 to 0
          expect(controller.selection.baseOffset, equals(6));
          expect(controller.selection.extentOffset, equals(0));
        },
      );
    });

    test('Shift+End selects to line end', () async {
      await testNocterm(
        'shift end',
        (tester) async {
          final controller = TextEditingController(text: 'Hello World');
          controller.selection = TextSelection.collapsed(offset: 6);

          await tester.pumpComponent(
            TextField(
              controller: controller,
              focused: true,
              decoration: InputDecoration(
                border: BoxBorder.all(),
              ),
            ),
          );

          // Shift+End
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.end,
            modifiers: const ModifierKeys(shift: true),
          ));
          await tester.pump();

          // Selection should extend from 6 to 11
          expect(controller.selection.baseOffset, equals(6));
          expect(controller.selection.extentOffset, equals(11));
        },
      );
    });

    test('Ctrl+Shift+Left selects previous word', () async {
      await testNocterm(
        'ctrl shift left',
        (tester) async {
          final controller = TextEditingController(text: 'Hello World');
          controller.selection = TextSelection.collapsed(offset: 11); // end

          await tester.pumpComponent(
            TextField(
              controller: controller,
              focused: true,
              decoration: InputDecoration(
                border: BoxBorder.all(),
              ),
            ),
          );

          // Ctrl+Shift+Left
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.arrowLeft,
            modifiers: const ModifierKeys(ctrl: true, shift: true),
          ));
          await tester.pump();

          // Should select "World" (offset 6-11)
          expect(controller.selection.baseOffset, equals(11));
          expect(controller.selection.extentOffset, equals(6));
        },
      );
    });

    test('Ctrl+Shift+Right selects next word', () async {
      await testNocterm(
        'ctrl shift right',
        (tester) async {
          final controller = TextEditingController(text: 'Hello World');
          controller.selection = TextSelection.collapsed(offset: 0);

          await tester.pumpComponent(
            TextField(
              controller: controller,
              focused: true,
              decoration: InputDecoration(
                border: BoxBorder.all(),
              ),
            ),
          );

          // Ctrl+Shift+Right
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.arrowRight,
            modifiers: const ModifierKeys(ctrl: true, shift: true),
          ));
          await tester.pump();

          // Should select "Hello " (offset 0-6) - word navigation moves to start of next word
          expect(controller.selection.baseOffset, equals(0));
          expect(controller.selection.extentOffset, equals(6));
        },
      );
    });

    test('Ctrl+Home moves to document start', () async {
      await testNocterm(
        'ctrl home',
        (tester) async {
          final controller = TextEditingController(text: 'Line1\nLine2\nLine3');
          controller.selection = TextSelection.collapsed(offset: 12);

          await tester.pumpComponent(
            TextField(
              controller: controller,
              focused: true,
              maxLines: 5,
              decoration: InputDecoration(
                border: BoxBorder.all(),
              ),
            ),
          );

          // Ctrl+Home
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.home,
            modifiers: const ModifierKeys(ctrl: true),
          ));
          await tester.pump();

          // Cursor should be at start
          expect(controller.selection.isCollapsed, isTrue);
          expect(controller.selection.extentOffset, equals(0));
        },
      );
    });

    test('Ctrl+End moves to document end', () async {
      await testNocterm(
        'ctrl end',
        (tester) async {
          final controller = TextEditingController(text: 'Line1\nLine2\nLine3');
          controller.selection = TextSelection.collapsed(offset: 0);

          await tester.pumpComponent(
            TextField(
              controller: controller,
              focused: true,
              maxLines: 5,
              decoration: InputDecoration(
                border: BoxBorder.all(),
              ),
            ),
          );

          // Ctrl+End
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.end,
            modifiers: const ModifierKeys(ctrl: true),
          ));
          await tester.pump();

          // Cursor should be at end
          expect(controller.selection.isCollapsed, isTrue);
          expect(controller.selection.extentOffset, equals(17));
        },
      );
    });

    test('Ctrl+Shift+Home selects to document start', () async {
      await testNocterm(
        'ctrl shift home',
        (tester) async {
          final controller = TextEditingController(text: 'Line1\nLine2\nLine3');
          controller.selection = TextSelection.collapsed(offset: 12);

          await tester.pumpComponent(
            TextField(
              controller: controller,
              focused: true,
              maxLines: 5,
              decoration: InputDecoration(
                border: BoxBorder.all(),
              ),
            ),
          );

          // Ctrl+Shift+Home
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.home,
            modifiers: const ModifierKeys(ctrl: true, shift: true),
          ));
          await tester.pump();

          // Selection should extend from 12 to 0
          expect(controller.selection.baseOffset, equals(12));
          expect(controller.selection.extentOffset, equals(0));
        },
      );
    });

    test('Ctrl+Shift+End selects to document end', () async {
      await testNocterm(
        'ctrl shift end',
        (tester) async {
          final controller = TextEditingController(text: 'Line1\nLine2\nLine3');
          controller.selection = TextSelection.collapsed(offset: 6);

          await tester.pumpComponent(
            TextField(
              controller: controller,
              focused: true,
              maxLines: 5,
              decoration: InputDecoration(
                border: BoxBorder.all(),
              ),
            ),
          );

          // Ctrl+Shift+End
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.end,
            modifiers: const ModifierKeys(ctrl: true, shift: true),
          ));
          await tester.pump();

          // Selection should extend from 6 to 17
          expect(controller.selection.baseOffset, equals(6));
          expect(controller.selection.extentOffset, equals(17));
        },
      );
    });
  });
}
