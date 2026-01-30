import 'dart:convert';
import 'dart:io';

import 'package:nocterm/nocterm.dart';

/// Static Layout Benchmark
///
/// Tests: Initial render performance, layout engine efficiency
/// Layout: Fixed 80x24 with styled boxes, borders, and text
void main() async {
  await runApp(const StaticLayoutApp());
}

class StaticLayoutApp extends StatefulComponent {
  const StaticLayoutApp({super.key});

  @override
  State<StaticLayoutApp> createState() => _StaticLayoutAppState();
}

class _StaticLayoutAppState extends State<StaticLayoutApp> {
  bool _firstFrameEmitted = false;
  late final Stopwatch _stopwatch;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
  }

  void _emitFirstFrame() {
    if (!_firstFrameEmitted) {
      _firstFrameEmitted = true;
      final startupMs = _stopwatch.elapsedMicroseconds / 1000;
      stderr.writeln(jsonEncode({'event': 'first_frame', 'timeMs': startupMs}));
    }
  }

  @override
  Component build(BuildContext context) {
    // Emit first frame timing after build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _emitFirstFrame();
    });

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.keyQ) {
          shutdownApp();
          return true;
        }
        return false;
      },
      child: Container(
        width: 80,
        height: 24,
        decoration: BoxDecoration(
          color: Color(0xFF1a1a2e),
        ),
        child: Column(
          children: [
            // Title bar
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: Color(0xFF16213e),
                border: BoxBorder(bottom: BorderSide(color: Color(0xFF0f3460))),
              ),
              child: Center(
                child: Text(
                  'Static Layout Benchmark',
                  style: TextStyle(
                    color: Color(0xFFe94560),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Divider
            Container(
              height: 1,
              decoration: BoxDecoration(color: Color(0xFF0f3460)),
            ),
            // Main content area
            Expanded(
              child: Row(
                children: [
                  // Left panel
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: BoxBorder(
                          right: BorderSide(color: Color(0xFF0f3460)),
                        ),
                      ),
                      padding: EdgeInsets.all(1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Left Panel',
                            style: TextStyle(
                              color: Color(0xFF53d8fb),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'This is a static layout',
                            style: TextStyle(color: Color(0xFFa0a0a0)),
                          ),
                          Text(
                            'with fixed dimensions.',
                            style: TextStyle(color: Color(0xFFa0a0a0)),
                          ),
                          SizedBox(height: 1),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: Color(0xFF0f3460),
                              border: BoxBorder.all(color: Color(0xFF53d8fb)),
                            ),
                            child: Text(
                              'Info Box',
                              style: TextStyle(color: Color(0xFFffffff)),
                            ),
                          ),
                          Spacer(),
                          Text(
                            'Status: Ready',
                            style: TextStyle(color: Color(0xFF4ade80)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Right panel
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Right Panel',
                            style: TextStyle(
                              color: Color(0xFFfbbf24),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Testing render',
                            style: TextStyle(color: Color(0xFFa0a0a0)),
                          ),
                          Text(
                            'performance metrics.',
                            style: TextStyle(color: Color(0xFFa0a0a0)),
                          ),
                          SizedBox(height: 1),
                          // Styled items
                          _buildItem('Item 1', Color(0xFF22c55e)),
                          _buildItem('Item 2', Color(0xFF3b82f6)),
                          _buildItem('Item 3', Color(0xFFa855f7)),
                          Spacer(),
                          Text(
                            'Press Q to quit',
                            style: TextStyle(
                              color: Color(0xFF6b7280),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Footer
            Container(
              height: 2,
              decoration: BoxDecoration(
                color: Color(0xFF16213e),
                border: BoxBorder(top: BorderSide(color: Color(0xFF0f3460))),
              ),
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nocterm v0.4.4',
                    style: TextStyle(color: Color(0xFF6b7280)),
                  ),
                  Text(
                    '80x24',
                    style: TextStyle(color: Color(0xFF6b7280)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Component _buildItem(String text, Color color) {
    return Row(
      children: [
        Text('● ', style: TextStyle(color: color)),
        Text(text, style: TextStyle(color: Color(0xFFd1d5db))),
      ],
    );
  }
}
