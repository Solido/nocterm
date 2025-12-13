import 'dart:async';
import 'package:nocterm/nocterm.dart';

void main() async {
  await runApp(const KeyDebugDemo());
}

class KeyDebugDemo extends StatefulComponent {
  const KeyDebugDemo({super.key});

  @override
  State<KeyDebugDemo> createState() => _KeyDebugDemoState();
}

class _KeyDebugDemoState extends State<KeyDebugDemo> {
  final List<String> _events = [];
  final List<String> _rawBytes = [];
  StreamSubscription? _inputSub;

  @override
  void initState() {
    super.initState();
    // Listen to raw input stream after binding is initialized
    _inputSub = TerminalBinding.instance.input.listen((str) {
      final bytes = str.codeUnits;
      final hexBytes = bytes
          .map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}')
          .join(' ');
      setState(() {
        _rawBytes.insert(0, 'Raw: $hexBytes');
        if (_rawBytes.length > 8) _rawBytes.removeLast();
      });
    });
  }

  @override
  void dispose() {
    _inputSub?.cancel();
    super.dispose();
  }

  bool _handleKey(KeyboardEvent event) {
    setState(() {
      _events.insert(
          0,
          'Key: ${event.logicalKey.debugName} | '
          'Shift: ${event.isShiftPressed} | '
          'Ctrl: ${event.isControlPressed} | '
          'Alt: ${event.isAltPressed} | '
          'Char: ${event.character?.codeUnits}');
      if (_events.length > 10) {
        _events.removeLast();
      }
    });

    // Quit on Ctrl+Q
    if (event.matches(LogicalKey.keyQ, ctrl: true)) {
      TerminalBinding.instance.requestShutdown(0);
      return true;
    }

    return true;
  }

  @override
  Component build(BuildContext context) {
    return Focusable(
      focused: true,
      onKeyEvent: _handleKey,
      child: Container(
        padding: const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Keyboard Debug - Press any key to see details',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan),
            ),
            Text('Press Ctrl+Q to quit', style: TextStyle(color: Colors.gray)),
            Text(''),
            Text('Try: Shift+Enter, Enter, Ctrl+A, etc.',
                style: TextStyle(color: Colors.yellow)),
            Text(''),
            Text('Recent events:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ..._events
                .map((e) => Text(e, style: TextStyle(color: Colors.green))),
            Text(''),
            Text('Raw bytes:', style: TextStyle(fontWeight: FontWeight.bold)),
            ..._rawBytes
                .map((e) => Text(e, style: TextStyle(color: Colors.cyan))),
          ],
        ),
      ),
    );
  }
}
