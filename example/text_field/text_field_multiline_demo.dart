import 'package:nocterm/nocterm.dart';

void main() async {
  await runApp(const MultilineTextFieldDemo());
}

class MultilineTextFieldDemo extends StatefulComponent {
  const MultilineTextFieldDemo({super.key});

  @override
  State<MultilineTextFieldDemo> createState() => _MultilineTextFieldDemoState();
}

class _MultilineTextFieldDemoState extends State<MultilineTextFieldDemo> {
  final _singleLineController = TextEditingController();
  final _multiLineController = TextEditingController();

  int _focusedFieldIndex = 0;

  @override
  void initState() {
    super.initState();
    _multiLineController.text =
        'Try the keybindings!\nType some text, then Ctrl+Z to undo.';
  }

  @override
  void dispose() {
    _singleLineController.dispose();
    _multiLineController.dispose();
    super.dispose();
  }

  bool _handleGlobalKey(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.tab && !event.isShiftPressed) {
      setState(() {
        _focusedFieldIndex = (_focusedFieldIndex + 1) % 2;
      });
      return true;
    } else if (event.logicalKey == LogicalKey.tab && event.isShiftPressed) {
      setState(() {
        _focusedFieldIndex = (_focusedFieldIndex - 1 + 2) % 2;
      });
      return true;
    } else if (event.matches(LogicalKey.keyQ, ctrl: true)) {
      TerminalBinding.instance.requestShutdown(0);
      return true;
    }
    return false;
  }

  @override
  Component build(BuildContext context) {
    final lineCount = _multiLineController.text.split('\n').length;

    return Focusable(
      focused: true,
      onKeyEvent: _handleGlobalKey,
      child: Container(
        padding: const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Shift+Enter Multiline Demo',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan),
            ),
            const SizedBox(height: 1),

            // Instructions
            Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                border: BoxBorder.all(color: Colors.gray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Keybindings:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.yellow)),
                  Text('  Ctrl+Z / Ctrl+Y     = Undo / Redo'),
                  Text('  Ctrl+A              = Select all'),
                  Text('  Ctrl+C / Ctrl+X     = Copy / Cut'),
                  Text('  Ctrl+V              = Paste'),
                  Text('  Shift+Home/End      = Select to line start/end'),
                  Text('  Ctrl+Shift+Left/Right = Select word'),
                  Text('  Ctrl+Home/End       = Go to document start/end'),
                  Text('  Ctrl+Backspace/Del  = Delete word'),
                  Text('  Tab / Ctrl+Q        = Next field / Quit'),
                ],
              ),
            ),
            const SizedBox(height: 1),

            // Status
            Row(
              children: [
                Text('Lines: ', style: TextStyle(color: Colors.gray)),
                Text('$lineCount', style: TextStyle(color: Colors.blue)),
                Text('  |  Undo: ', style: TextStyle(color: Colors.gray)),
                Text(_multiLineController.canUndo ? 'Yes' : 'No',
                    style: TextStyle(
                        color: _multiLineController.canUndo
                            ? Colors.green
                            : Colors.red)),
                Text('  |  Redo: ', style: TextStyle(color: Colors.gray)),
                Text(_multiLineController.canRedo ? 'Yes' : 'No',
                    style: TextStyle(
                        color: _multiLineController.canRedo
                            ? Colors.green
                            : Colors.red)),
              ],
            ),
            const SizedBox(height: 1),

            // Single-line field
            Text('Single-line field:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('(Shift+Enter does nothing here)',
                style: TextStyle(color: Colors.gray)),
            TextField(
              controller: _singleLineController,
              focused: _focusedFieldIndex == 0,
              placeholder: 'Single line - Enter submits',
              width: 50,
              maxLines: 1,
              decoration: InputDecoration(
                border: BoxBorder.all(color: Colors.gray),
                focusedBorder: BoxBorder.all(color: Colors.green),
                contentPadding: const EdgeInsets.symmetric(horizontal: 1),
              ),
              onSubmitted: (value) {
                setState(() => _focusedFieldIndex = 1);
              },
            ),

            const SizedBox(height: 1),

            // Multi-line field
            Text('Multi-line field (5 lines max):',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('(Shift+Enter inserts new line)',
                style: TextStyle(color: Colors.gray)),
            TextField(
              controller: _multiLineController,
              focused: _focusedFieldIndex == 1,
              placeholder: 'Multi-line - Shift+Enter for new line',
              width: 50,
              maxLines: 5,
              decoration: InputDecoration(
                border: BoxBorder.all(color: Colors.gray),
                focusedBorder: BoxBorder.all(color: Colors.green),
                contentPadding: const EdgeInsets.all(1),
              ),
              onChanged: (value) {
                setState(() {
                  // Just trigger rebuild to update line count
                });
              },
              onSubmitted: (value) {
                setState(() => _focusedFieldIndex = 0);
              },
            ),

            const SizedBox(height: 1),

            // Content preview
            Text('Content preview:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              width: 50,
              height: 5,
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                border: BoxBorder.all(color: Colors.blue),
              ),
              child: Text(
                _multiLineController.text.isEmpty
                    ? '(empty)'
                    : _multiLineController.text.replaceAll('\n', '\\n\n'),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
