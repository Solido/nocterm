import 'dart:convert';
import 'dart:io';

import 'package:nocterm/nocterm.dart';

/// Rapid Input Benchmark
///
/// Tests: Keystroke-to-render latency, input handling performance
/// Interaction: Text input field with real-time display
void main() async {
  await runApp(const RapidInputApp());
}

class RapidInputApp extends StatefulComponent {
  const RapidInputApp({super.key});

  @override
  State<RapidInputApp> createState() => _RapidInputAppState();
}

class _RapidInputAppState extends State<RapidInputApp> {
  final TextEditingController _controller = TextEditingController();
  bool _firstFrameEmitted = false;
  late final Stopwatch _stopwatch;
  int _keystrokeCount = 0;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _emitFirstFrame() {
    if (!_firstFrameEmitted) {
      _firstFrameEmitted = true;
      final startupMs = _stopwatch.elapsedMicroseconds / 1000;
      stderr.writeln(jsonEncode({'event': 'first_frame', 'timeMs': startupMs}));
    }
  }

  void _onTextChanged() {
    NoctermTimeline.startSync('text_change');
    _keystrokeCount++;
    final timeMs = _stopwatch.elapsedMicroseconds / 1000;
    stderr.writeln(jsonEncode({
      'event': 'keystroke',
      'timeMs': timeMs,
      'keystrokeCount': _keystrokeCount,
      'textLength': _controller.text.length,
    }));
    setState(() {}); // Force rebuild to update stats display
    NoctermTimeline.finishSync();
  }

  @override
  Component build(BuildContext context) {
    // Emit first frame timing after build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _emitFirstFrame();
    });

    return Focusable(
      focused: false, // TextField will handle focus
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.escape) {
          shutdownApp();
          return true;
        }
        return false;
      },
      child: Container(
        decoration: BoxDecoration(color: Color(0xFF0f0f23)),
        child: Column(
          children: [
            // Header
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: Color(0xFF1a1a2e),
                border:
                    BoxBorder(bottom: BorderSide(color: Color(0xFFf59e0b))),
              ),
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rapid Input Benchmark',
                    style: TextStyle(
                      color: Color(0xFFf59e0b),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Keystrokes: $_keystrokeCount',
                    style: TextStyle(color: Color(0xFF6b7280)),
                  ),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: Container(
                padding: EdgeInsets.all(2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Type as fast as you can:',
                      style: TextStyle(color: Color(0xFFa0a0a0)),
                    ),
                    SizedBox(height: 2),
                    // Input field
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Color(0xFF1a1a2e),
                        border: BoxBorder.all(color: Color(0xFFf59e0b)),
                      ),
                      child: TextField(
                        controller: _controller,
                        focused: true,
                        style: TextStyle(color: Color(0xFFffffff)),
                        cursorColor: Color(0xFFf59e0b),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 1),
                        ),
                      ),
                    ),
                    SizedBox(height: 2),
                    // Stats display
                    Container(
                      padding: EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Color(0xFF1a1a2e),
                        border: BoxBorder.all(color: Color(0xFF374151)),
                      ),
                      child: Column(
                        children: [
                          _buildStatRow(
                              'Characters', '${_controller.text.length}'),
                          _buildStatRow('Keystrokes', '$_keystrokeCount'),
                          _buildStatRow(
                            'Time Elapsed',
                            '${(_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
                          ),
                          if (_controller.text.isNotEmpty &&
                              _stopwatch.elapsedMilliseconds > 1000)
                            _buildStatRow(
                              'Chars/sec',
                              '${(_controller.text.length / (_stopwatch.elapsedMilliseconds / 1000)).toStringAsFixed(1)}',
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 2),
                    // Preview
                    Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: Color(0xFF0f0f23),
                        border: BoxBorder.all(color: Color(0xFF374151)),
                      ),
                      padding: EdgeInsets.all(1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preview:',
                            style: TextStyle(color: Color(0xFF6b7280)),
                          ),
                          Text(
                            _controller.text.isEmpty
                                ? '(empty)'
                                : _controller.text.length > 60
                                    ? '${_controller.text.substring(0, 60)}...'
                                    : _controller.text,
                            style: TextStyle(
                              color: _controller.text.isEmpty
                                  ? Color(0xFF4b5563)
                                  : Color(0xFFffffff),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              height: 2,
              decoration: BoxDecoration(
                color: Color(0xFF1a1a2e),
                border: BoxBorder(top: BorderSide(color: Color(0xFFf59e0b))),
              ),
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Type to test input latency',
                    style: TextStyle(color: Color(0xFF6b7280)),
                  ),
                  Text(
                    'ESC to quit',
                    style: TextStyle(color: Color(0xFF4b5563)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Component _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Color(0xFF6b7280))),
        Text(value, style: TextStyle(color: Color(0xFFffffff))),
      ],
    );
  }
}
