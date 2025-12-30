import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Enhanced cursor demo with focus tracking
///
/// Uses xterm focus reporting (CSI ? 1004 h) to detect when terminal
/// gains/loses focus, and reapplies cursor when focus is regained.
///
/// Run with: dart run example/cgs_cursor_focus_demo.dart

// CGS types and functions (same as before)
typedef CGSConnectionID = Int32;
typedef CGSMainConnectionIDNative = Int32 Function();
typedef CGSMainConnectionIDDart = int Function();
typedef CGSSetSystemDefinedCursorNative = Int32 Function(
    Int32 cid, Int32 cursor);
typedef CGSSetSystemDefinedCursorDart = int Function(int cid, int cursor);
typedef CGSSetConnectionPropertyNative = Int32 Function(
    Int32 cid, Int32 targetCid, Pointer key, Pointer value);
typedef CGSSetConnectionPropertyDart = int Function(
    int cid, int targetCid, Pointer key, Pointer value);
typedef CFStringCreateWithCStringNative = Pointer Function(
    Pointer alloc, Pointer<Utf8> cStr, Uint32 encoding);
typedef CFStringCreateWithCStringDart = Pointer Function(
    Pointer alloc, Pointer<Utf8> cStr, int encoding);

class CGSCursor {
  static const int arrow = 0;
  static const int iBeam = 1;
  static const int crosshair = 5; // Note: IDs may vary
  static const int pointingHand = 10;
  static const int wait = 7;
}

// Current cursor state
int _currentCursorId = CGSCursor.arrow;
int _connectionId = 0;
CGSSetSystemDefinedCursorDart? _setCursor;

void main() async {
  print('CGS Cursor with Focus Tracking Demo');
  print('====================================\n');

  if (!Platform.isMacOS) {
    print('This demo only works on macOS');
    return;
  }

  try {
    // Initialize CGS
    final coreGraphics = DynamicLibrary.open(
        '/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics');
    final coreFoundation = DynamicLibrary.open(
        '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation');

    final cgsMainConnectionID = coreGraphics.lookupFunction<
        CGSMainConnectionIDNative,
        CGSMainConnectionIDDart>('CGSMainConnectionID');

    _connectionId = cgsMainConnectionID();
    print('CGS connection ID: $_connectionId');

    // Set up SetsCursorInBackground
    final cgsSetConnectionProperty = coreGraphics.lookupFunction<
        CGSSetConnectionPropertyNative,
        CGSSetConnectionPropertyDart>('CGSSetConnectionProperty');

    final cfStringCreate = coreFoundation.lookupFunction<
        CFStringCreateWithCStringNative,
        CFStringCreateWithCStringDart>('CFStringCreateWithCString');

    final kCFBooleanTruePtr = coreFoundation.lookup<Pointer>('kCFBooleanTrue');
    final kCFBooleanTrue = kCFBooleanTruePtr.value;

    final keyStr = 'SetsCursorInBackground'.toNativeUtf8();
    final cfKey = cfStringCreate(nullptr, keyStr, 0x08000100);
    cgsSetConnectionProperty(
        _connectionId, _connectionId, cfKey, kCFBooleanTrue);
    print('Enabled SetsCursorInBackground');

    _setCursor = coreGraphics.lookupFunction<CGSSetSystemDefinedCursorNative,
        CGSSetSystemDefinedCursorDart>('CGSSetSystemDefinedCursor');

    // Enable raw mode
    stdin.echoMode = false;
    stdin.lineMode = false;

    // Enable focus reporting: CSI ? 1004 h
    stdout.write('\x1b[?1004h');
    print('Enabled focus reporting (ESC[?1004h)');
    print('');
    print('When you switch tabs/windows, the terminal will send:');
    print('  Focus IN:  ESC [ I');
    print('  Focus OUT: ESC [ O');
    print('');

    print('--- Interactive Mode ---');
    print('Press keys to change cursor:');
    print('  a = arrow    t = I-beam    w = wait');
    print('  q = quit');
    print('');
    print('Try: Set a cursor, switch Warp tabs, switch back!');
    print('The cursor should be reapplied when you return.\n');

    // Buffer for parsing escape sequences
    final buffer = <int>[];
    bool inEscape = false;

    await for (final input in stdin) {
      for (final byte in input) {
        // Check for escape sequence start
        if (byte == 0x1b) {
          inEscape = true;
          buffer.clear();
          buffer.add(byte);
          continue;
        }

        if (inEscape) {
          buffer.add(byte);

          // Check for focus sequences: ESC [ I or ESC [ O
          if (buffer.length >= 3) {
            final seq = String.fromCharCodes(buffer);

            if (seq == '\x1b[I') {
              // Focus gained!
              print('>>> FOCUS IN - Reapplying cursor: $_currentCursorId');
              _applyCursor();
              inEscape = false;
              buffer.clear();
              continue;
            } else if (seq == '\x1b[O') {
              // Focus lost
              print('>>> FOCUS OUT');
              inEscape = false;
              buffer.clear();
              continue;
            }
          }

          // Give up on escape after 10 bytes
          if (buffer.length > 10) {
            inEscape = false;
            buffer.clear();
          }
          continue;
        }

        // Regular key handling
        final char = String.fromCharCode(byte);

        if (char == 'q') {
          // Cleanup
          stdout.write('\x1b[?1004l'); // Disable focus reporting
          _setCursor?.call(_connectionId, CGSCursor.arrow);
          stdin.echoMode = true;
          stdin.lineMode = true;
          print('\nDisabled focus reporting. Goodbye!');
          return;
        }

        switch (char) {
          case 'a':
            _currentCursorId = CGSCursor.arrow;
            _applyCursor();
            print('Set to arrow');
          case 't':
            _currentCursorId = CGSCursor.iBeam;
            _applyCursor();
            print('Set to I-beam');
          case 'w':
            _currentCursorId = CGSCursor.wait;
            _applyCursor();
            print('Set to wait');
        }
      }
    }
  } catch (e, stack) {
    print('Error: $e');
    print(stack);
  }
}

void _applyCursor() {
  _setCursor?.call(_connectionId, _currentCursorId);
}
