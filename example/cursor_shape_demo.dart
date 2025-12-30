import 'dart:io';

/// Demo script to test cursor shape escape sequences (DECSCUSR)
///
/// Run with: dart run example/cursor_shape_demo.dart
void main() async {
  // Enable raw mode for better control
  stdin.echoMode = false;
  stdin.lineMode = false;

  print('Cursor Shape Demo (DECSCUSR)');
  print('============================\n');
  print('Watch the cursor shape change!\n');

  final shapes = [
    (1, 'Blinking Block'),
    (2, 'Steady Block'),
    (3, 'Blinking Underline'),
    (4, 'Steady Underline'),
    (5, 'Blinking Bar (I-beam)'),
    (6, 'Steady Bar (I-beam)'),
  ];

  for (final (code, name) in shapes) {
    // Set cursor shape: ESC [ N SP q
    stdout.write('\x1b[$code q');
    stdout.write('Cursor style $code: $name');
    stdout.write(' <-- Look at the cursor here');
    print('');

    // Wait a bit so you can see each shape
    await Future.delayed(Duration(seconds: 2));
  }

  print('\n--- Interactive Mode ---');
  print('Press 1-6 to change cursor, q to quit:\n');

  // Reset to blinking block
  stdout.write('\x1b[1 q');

  // Listen for keypresses
  await for (final input in stdin) {
    final char = String.fromCharCode(input.first);

    if (char == 'q') {
      break;
    }

    final code = int.tryParse(char);
    if (code != null && code >= 1 && code <= 6) {
      stdout.write('\x1b[$code q');
      print('Changed to style $code: ${shapes[code - 1].$2}');
    }
  }

  // Reset cursor to default and restore terminal
  stdout.write('\x1b[0 q'); // Reset to default
  stdin.echoMode = true;
  stdin.lineMode = true;

  print('\nCursor reset to default. Goodbye!');
}
