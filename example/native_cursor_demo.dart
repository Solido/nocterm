import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Proof-of-concept: Can we control the mouse cursor from a CLI app via FFI?
///
/// This explores using macOS native APIs to change the cursor system-wide,
/// bypassing terminal escape sequence limitations.
///
/// Run with: dart run example/native_cursor_demo.dart

// objc_msgSend - Send a message to an Objective-C object
typedef ObjcMsgSendNoArgsC = Pointer Function(Pointer obj, Pointer sel);
typedef ObjcMsgSendNoArgsDart = Pointer Function(Pointer obj, Pointer sel);

void main() async {
  print('Native Cursor Control Demo (macOS FFI)');
  print('=======================================\n');

  if (!Platform.isMacOS) {
    print('This demo only works on macOS');
    return;
  }

  try {
    // Get the objc runtime functions
    final libobjc = DynamicLibrary.open('/usr/lib/libobjc.A.dylib');

    final objc_getClass = libobjc.lookupFunction<
        Pointer Function(Pointer<Utf8> name),
        Pointer Function(Pointer<Utf8> name)>('objc_getClass');

    final sel_registerName = libobjc.lookupFunction<
        Pointer Function(Pointer<Utf8> name),
        Pointer Function(Pointer<Utf8> name)>('sel_registerName');

    final objc_msgSend =
        libobjc.lookupFunction<ObjcMsgSendNoArgsC, ObjcMsgSendNoArgsDart>(
            'objc_msgSend');

    // Helper to create a selector
    Pointer sel(String name) => sel_registerName(name.toNativeUtf8());

    // Helper to get a class
    Pointer cls(String name) => objc_getClass(name.toNativeUtf8());

    print('Step 1: Getting NSCursor class...');
    final nsCursorClass = cls('NSCursor');
    print(
        '  NSCursor class: ${nsCursorClass.address != 0 ? "FOUND" : "NOT FOUND"}');
    if (nsCursorClass.address == 0) {
      print(
          '  -> NSCursor requires AppKit, which may not be loaded in CLI context');
    }

    print('\nStep 2: Getting cursor instances...');
    final cursors = [
      'arrowCursor',
      'IBeamCursor',
      'crosshairCursor',
      'pointingHandCursor'
    ];
    for (final name in cursors) {
      final cursor = objc_msgSend(nsCursorClass, sel(name));
      print(
          '  $name: ${cursor.address != 0 ? "OK (${cursor.address})" : "null"}');
    }

    print('\nStep 3: Trying to hide/show system cursor...');
    // Try class methods to hide/show cursor
    objc_msgSend(nsCursorClass, sel('hide'));
    print('  Called [NSCursor hide]');

    await Future.delayed(Duration(seconds: 2));

    objc_msgSend(nsCursorClass, sel('unhide'));
    print('  Called [NSCursor unhide]');

    print('\nStep 4: Interactive test...');
    print('Move your mouse around. Did the cursor hide for 2 seconds?');
    print('');
    print('Press Enter to try setting cursor to I-beam...');
    stdin.readLineSync();

    final ibeam = objc_msgSend(nsCursorClass, sel('IBeamCursor'));
    if (ibeam.address != 0) {
      objc_msgSend(ibeam, sel('set'));
      print('Called [IBeamCursor set]');
      print('');
      print(
          'Did the cursor change? (Likely not - we\'re not the frontmost app!)');
    }

    print('\n--- ANALYSIS ---');
    print(
        'The challenge: NSCursor methods only work when YOUR app is frontmost.');
    print(
        'But WE are running inside Terminal.app/Warp/Kitty, so THEY are frontmost.');
    print('');
    print('Possible workarounds:');
    print(
        '1. Use private CGS APIs (like screencapture does) - not App Store safe');
    print('2. Find a way to tell the terminal app to change its cursor');
    print('3. Use OSC 22 escape sequences (Kitty/modern terminals only)');
    print('');
    print('The terminal IS the window owner, so it controls the cursor.');
  } catch (e, stack) {
    print('Error: $e');
    print(stack);
  }

  print('\nDone!');
}
