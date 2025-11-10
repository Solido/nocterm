import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart' hide isNotEmpty;

void main() {
  test('verify syntax highlighting produces colored output', () async {
    await testNocterm(
      'dart highlighting with colors',
      (tester) async {
        await tester.pumpComponent(
          const SyntaxHighlightText(
            code: 'void main() { final x = "hello"; }',
            language: 'dart',
          ),
        );

        // Get the terminal buffer
        final buffer = tester.terminalState.buffer;

        // Check that we have styled cells (not all default color)
        var styledCells = <String>[];
        for (int y = 0; y < buffer.height; y++) {
          for (int x = 0; x < buffer.width; x++) {
            final cell = buffer.getCell(x, y);
            if (cell != null && cell.char.isNotEmpty && cell.char.trim().isNotEmpty) {
              // Check if cell has color styling
              if (cell.style.color != null) {
                styledCells.add('cell at ($x, $y): "${cell.char}" with color ${cell.style.color}');
              }
            }
          }
        }

        print('\nStyled cells found: ${styledCells.length}');
        for (var info in styledCells.take(10)) {
          print('  $info');
        }

        expect(styledCells.length, greaterThan(0),
            reason: 'Expected to find at least one styled cell with syntax highlighting');
      },
      debugPrintAfterPump: true,
    );
  });
}
