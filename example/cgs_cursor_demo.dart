import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Proof-of-concept: System-wide cursor control using CGS private APIs
///
/// This uses undocumented CoreGraphics Services APIs to control the cursor
/// system-wide, bypassing the normal NSCursor frontmost-app restriction.
///
/// The key trick is using CGSSetConnectionProperty to set "SetsCursorInBackground"
/// which tells WindowServer we're allowed to control the cursor from background.
///
/// WARNING: These are PRIVATE APIs that:
/// - Will get your app rejected from the Mac App Store
/// - May break in future macOS versions
/// - Work without SIP disabled (for basic operations)
///
/// Run with: dart run example/cgs_cursor_demo.dart

// CGS types
typedef CGSConnectionID = Int32;
typedef CGError = Int32;
typedef CGSCursorID = Int32;

// CGSMainConnectionID() -> CGSConnectionID
typedef CGSMainConnectionIDNative = Int32 Function();
typedef CGSMainConnectionIDDart = int Function();

// CGSShowCursor(CGSConnectionID) -> CGError
typedef CGSShowCursorNative = Int32 Function(Int32 cid);
typedef CGSShowCursorDart = int Function(int cid);

// CGSHideCursor(CGSConnectionID) -> CGError
typedef CGSHideCursorNative = Int32 Function(Int32 cid);
typedef CGSHideCursorDart = int Function(int cid);

// CGSObscureCursor(CGSConnectionID) -> CGError (hide until mouse moves)
typedef CGSObscureCursorNative = Int32 Function(Int32 cid);
typedef CGSObscureCursorDart = int Function(int cid);

// CGSSetSystemDefinedCursor(CGSConnectionID, CGSCursorID) -> CGError
typedef CGSSetSystemDefinedCursorNative = Int32 Function(
    Int32 cid, Int32 cursor);
typedef CGSSetSystemDefinedCursorDart = int Function(int cid, int cursor);

// CGSSetConnectionProperty(CGSConnectionID, CGSConnectionID, CFStringRef key, CFTypeRef value) -> CGError
typedef CGSSetConnectionPropertyNative = Int32 Function(
    Int32 cid, Int32 targetCid, Pointer key, Pointer value);
typedef CGSSetConnectionPropertyDart = int Function(
    int cid, int targetCid, Pointer key, Pointer value);

// CFStringCreateWithCString
typedef CFStringCreateWithCStringNative = Pointer Function(
    Pointer alloc, Pointer<Utf8> cStr, Uint32 encoding);
typedef CFStringCreateWithCStringDart = Pointer Function(
    Pointer alloc, Pointer<Utf8> cStr, int encoding);

// CFBooleanGetValue / kCFBooleanTrue
typedef CFBooleanGetTypeIDNative = Uint64 Function();
typedef CFBooleanGetTypeIDDart = int Function();

// System cursor IDs (from CGSInternal)
class CGSCursor {
  static const int arrow = 0; // Standard arrow
  static const int iBeam = 1; // Text I-beam
  static const int iBeamXOR = 2; // I-beam XOR variant
  static const int alias = 3; // Alias arrow
  static const int copy = 4; // Copy arrow
  static const int move = 5; // Move cursor
  static const int arrowContext = 6; // Contextual menu arrow
  static const int wait = 7; // Wait/busy cursor
  static const int empty = 8; // Empty/hidden cursor
  // More cursors (9-44) include resize cursors, hands, zoom, etc.
  static const int pointingHand = 10; // Pointing hand (link cursor)
  static const int openHand = 11; // Open hand (grab)
  static const int closedHand = 12; // Closed hand (grabbing)
  static const int crosshair = 13; // Crosshair
}

void main() async {
  print('CGS Private API Cursor Demo (with SetsCursorInBackground)');
  print('==========================================================\n');

  if (!Platform.isMacOS) {
    print('This demo only works on macOS');
    return;
  }

  try {
    // Load frameworks
    final coreGraphics = DynamicLibrary.open(
        '/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics');
    final coreFoundation = DynamicLibrary.open(
        '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation');

    print('Loaded CoreGraphics and CoreFoundation frameworks');

    // Look up CGSMainConnectionID
    late CGSMainConnectionIDDart cgsMainConnectionID;
    try {
      cgsMainConnectionID = coreGraphics.lookupFunction<
          CGSMainConnectionIDNative,
          CGSMainConnectionIDDart>('CGSMainConnectionID');
      print('Found CGSMainConnectionID');
    } catch (e) {
      print('CGSMainConnectionID not found - trying _CGSDefaultConnection');
      cgsMainConnectionID = coreGraphics.lookupFunction<
          CGSMainConnectionIDNative,
          CGSMainConnectionIDDart>('_CGSDefaultConnection');
    }

    // Get connection ID
    final connectionId = cgsMainConnectionID();
    print('Got CGS connection ID: $connectionId');

    if (connectionId == 0) {
      print('WARNING: Connection ID is 0 - this may indicate a problem');
      return;
    }

    // Look up CGSSetConnectionProperty - THE KEY TO BACKGROUND CURSOR CONTROL
    CGSSetConnectionPropertyDart? cgsSetConnectionProperty;
    try {
      cgsSetConnectionProperty = coreGraphics.lookupFunction<
          CGSSetConnectionPropertyNative,
          CGSSetConnectionPropertyDart>('CGSSetConnectionProperty');
      print('Found CGSSetConnectionProperty');
    } catch (e) {
      print('CGSSetConnectionProperty not found: $e');
    }

    // Look up CFStringCreateWithCString
    final cfStringCreate = coreFoundation.lookupFunction<
        CFStringCreateWithCStringNative,
        CFStringCreateWithCStringDart>('CFStringCreateWithCString');

    // Get kCFBooleanTrue
    final kCFBooleanTruePtr = coreFoundation.lookup<Pointer>('kCFBooleanTrue');
    final kCFBooleanTrue = kCFBooleanTruePtr.value;
    print('Got kCFBooleanTrue: $kCFBooleanTrue');

    // Set "SetsCursorInBackground" property - this is the magic!
    if (cgsSetConnectionProperty != null) {
      print('\n*** Setting SetsCursorInBackground property ***');

      // Create CFString for the property key
      final keyStr = 'SetsCursorInBackground'.toNativeUtf8();
      final cfKey =
          cfStringCreate(nullptr, keyStr, 0x08000100); // kCFStringEncodingUTF8

      if (cfKey != nullptr) {
        final result = cgsSetConnectionProperty(
            connectionId, connectionId, cfKey, kCFBooleanTrue);
        print('CGSSetConnectionProperty returned: $result (0 = success)');

        if (result == 0) {
          print(
              'SUCCESS! We should now be able to set cursors from background!\n');
        }
      } else {
        print('Failed to create CFString for key');
      }
    }

    // Look up cursor functions
    CGSShowCursorDart? cgsShowCursor;
    CGSHideCursorDart? cgsHideCursor;
    CGSObscureCursorDart? cgsObscureCursor;
    CGSSetSystemDefinedCursorDart? cgsSetSystemDefinedCursor;

    try {
      cgsShowCursor =
          coreGraphics.lookupFunction<CGSShowCursorNative, CGSShowCursorDart>(
              'CGSShowCursor');
      print('Found CGSShowCursor');
    } catch (e) {
      print('CGSShowCursor not found: $e');
    }

    try {
      cgsHideCursor =
          coreGraphics.lookupFunction<CGSHideCursorNative, CGSHideCursorDart>(
              'CGSHideCursor');
      print('Found CGSHideCursor');
    } catch (e) {
      print('CGSHideCursor not found: $e');
    }

    try {
      cgsObscureCursor = coreGraphics.lookupFunction<CGSObscureCursorNative,
          CGSObscureCursorDart>('CGSObscureCursor');
      print('Found CGSObscureCursor');
    } catch (e) {
      print('CGSObscureCursor not found: $e');
    }

    try {
      cgsSetSystemDefinedCursor = coreGraphics.lookupFunction<
          CGSSetSystemDefinedCursorNative,
          CGSSetSystemDefinedCursorDart>('CGSSetSystemDefinedCursor');
      print('Found CGSSetSystemDefinedCursor');
    } catch (e) {
      print('CGSSetSystemDefinedCursor not found: $e');
    }

    print('\n--- Tests (with SetsCursorInBackground enabled) ---\n');

    // Test 1: Hide/Show cursor
    if (cgsHideCursor != null && cgsShowCursor != null) {
      print('Test 1: Hiding cursor for 2 seconds...');
      final hideResult = cgsHideCursor(connectionId);
      print('  CGSHideCursor returned: $hideResult');

      await Future.delayed(Duration(seconds: 2));

      final showResult = cgsShowCursor(connectionId);
      print('  CGSShowCursor returned: $showResult');
      print('  Did the cursor disappear?\n');
    }

    // Test 2: Change cursor type
    if (cgsSetSystemDefinedCursor != null) {
      print('Test 2: Changing cursor types...');
      print('  (Watch the cursor change as you hover over terminal!)\n');

      final cursors = [
        (CGSCursor.arrow, 'Arrow'),
        (CGSCursor.iBeam, 'I-Beam'),
        (CGSCursor.crosshair, 'Crosshair'),
        (CGSCursor.pointingHand, 'Pointing Hand'),
        (CGSCursor.openHand, 'Open Hand'),
        (CGSCursor.wait, 'Wait/Busy'),
        (CGSCursor.move, 'Move'),
        (CGSCursor.arrow, 'Arrow (reset)'),
      ];

      for (final (cursorId, name) in cursors) {
        print('  Setting cursor to: $name (ID: $cursorId)');
        final result = cgsSetSystemDefinedCursor(connectionId, cursorId);
        print('    Result: $result');
        await Future.delayed(Duration(milliseconds: 2000));
      }
    }

    print('\n--- Interactive Mode ---');
    print('Press keys to change cursor:');
    print('  a = arrow        t = I-beam (text)');
    print('  c = crosshair    p = pointing hand');
    print('  g = open hand    m = move');
    print('  w = wait/busy    x = closed hand');
    print('  h = HIDE cursor  s = SHOW cursor');
    print('  q = quit\n');

    stdin.echoMode = false;
    stdin.lineMode = false;

    await for (final input in stdin) {
      final char = String.fromCharCode(input.first);

      if (char == 'q') break;

      switch (char) {
        case 'a':
          cgsSetSystemDefinedCursor?.call(connectionId, CGSCursor.arrow);
          print('Set to arrow');
        case 't':
          cgsSetSystemDefinedCursor?.call(connectionId, CGSCursor.iBeam);
          print('Set to I-beam');
        case 'c':
          cgsSetSystemDefinedCursor?.call(connectionId, CGSCursor.crosshair);
          print('Set to crosshair');
        case 'p':
          cgsSetSystemDefinedCursor?.call(connectionId, CGSCursor.pointingHand);
          print('Set to pointing hand');
        case 'g':
          cgsSetSystemDefinedCursor?.call(connectionId, CGSCursor.openHand);
          print('Set to open hand');
        case 'x':
          cgsSetSystemDefinedCursor?.call(connectionId, CGSCursor.closedHand);
          print('Set to closed hand');
        case 'm':
          cgsSetSystemDefinedCursor?.call(connectionId, CGSCursor.move);
          print('Set to move');
        case 'w':
          cgsSetSystemDefinedCursor?.call(connectionId, CGSCursor.wait);
          print('Set to wait');
        case 'h':
          cgsHideCursor?.call(connectionId);
          print('HIDDEN - move mouse to another window and back');
        case 's':
          cgsShowCursor?.call(connectionId);
          print('SHOWN');
      }
    }

    // Reset cursor
    cgsSetSystemDefinedCursor?.call(connectionId, CGSCursor.arrow);
    cgsShowCursor?.call(connectionId);

    stdin.echoMode = true;
    stdin.lineMode = true;
  } catch (e, stack) {
    print('Error: $e');
    print(stack);
  }

  print('\nDone! Cursor should be reset to normal.');
}
