import 'dart:io';

/// Demo script to test mouse pointer cursor shape escape sequences (OSC 22)
///
/// This works in Kitty and some other modern terminals.
/// May NOT work in: basic xterm, macOS Terminal.app, older terminals
///
/// Run with: dart run example/mouse_pointer_demo.dart
void main() async {
  // Enable raw mode
  stdin.echoMode = false;
  stdin.lineMode = false;

  print('Mouse Pointer Shape Demo (OSC 22)');
  print('==================================\n');
  print('NOTE: This only works in Kitty and some modern terminals!\n');
  print(
      'Move your mouse over this terminal window to see the pointer change.\n');

  // Common pointer shapes (CSS-based names)
  final shapes = [
    'default', // Normal arrow
    'pointer', // Hand/link cursor
    'text', // I-beam for text
    'crosshair', // Crosshair/precision
    'move', // Move cursor
    'grab', // Open hand (ready to grab)
    'grabbing', // Closed hand (grabbing)
    'not-allowed', // Circle with slash
    'wait', // Hourglass/spinner
    'progress', // Arrow with spinner
    'help', // Arrow with question mark
    'cell', // Cell/plus cursor
    'copy', // Arrow with plus
    'zoom-in', // Magnifier with plus
    'zoom-out', // Magnifier with minus
    'e-resize', // East resize arrow
    'ns-resize', // North-south resize
    'nwse-resize', // Diagonal resize
  ];

  for (final shape in shapes) {
    // Set pointer shape: OSC 22 ; shape ST
    // OSC = ESC ]
    // ST = ESC \
    stdout.write('\x1b]22;$shape\x1b\\');

    print('Pointer: "$shape" - move mouse over terminal to see');
    await Future.delayed(Duration(seconds: 2));
  }

  print('\n--- Interactive Mode ---');
  print('Press keys to change pointer:');
  print('  d = default (arrow)');
  print('  p = pointer (hand)');
  print('  t = text (I-beam)');
  print('  c = crosshair');
  print('  g = grab');
  print('  m = move');
  print('  w = wait');
  print('  n = not-allowed');
  print('  q = quit\n');

  // Reset to default
  stdout.write('\x1b]22;default\x1b\\');

  await for (final input in stdin) {
    final char = String.fromCharCode(input.first);

    String? shape;
    switch (char) {
      case 'd':
        shape = 'default';
      case 'p':
        shape = 'pointer';
      case 't':
        shape = 'text';
      case 'c':
        shape = 'crosshair';
      case 'g':
        shape = 'grab';
      case 'm':
        shape = 'move';
      case 'w':
        shape = 'wait';
      case 'n':
        shape = 'not-allowed';
      case 'q':
        break;
    }

    if (char == 'q') break;

    if (shape != null) {
      stdout.write('\x1b]22;$shape\x1b\\');
      print('Changed to: $shape');
    }
  }

  // Reset pointer and terminal
  stdout.write('\x1b]22;default\x1b\\');
  stdin.echoMode = true;
  stdin.lineMode = true;

  print('\nPointer reset to default. Goodbye!');
}
