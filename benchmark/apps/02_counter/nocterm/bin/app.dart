import 'dart:convert';
import 'dart:io';

import 'package:nocterm/nocterm.dart';

/// Counter Benchmark
///
/// Tests: Minimal state change performance, re-render efficiency
/// Interaction: Increment counter on any keypress
void main() async {
  await runApp(const CounterApp());
}

class CounterApp extends StatefulComponent {
  const CounterApp({super.key});

  @override
  State<CounterApp> createState() => _CounterAppState();
}

class _CounterAppState extends State<CounterApp> {
  int _counter = 0;
  bool _firstFrameEmitted = false;
  late final Stopwatch _stopwatch;
  int _lastEmittedCount = -1;

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

  void _emitStateChange() {
    if (_lastEmittedCount != _counter) {
      _lastEmittedCount = _counter;
      final timeMs = _stopwatch.elapsedMicroseconds / 1000;
      stderr.writeln(jsonEncode({
        'event': 'state_change',
        'timeMs': timeMs,
        'counter': _counter,
      }));
    }
  }

  void _increment() {
    NoctermTimeline.startSync('counter_increment');
    setState(() {
      _counter++;
    });
    NoctermTimeline.finishSync();
    _emitStateChange();
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
        _increment();
        return true;
      },
      child: Container(
        decoration: BoxDecoration(color: Color(0xFF0f0f23)),
        child: Center(
          child: Container(
            width: 40,
            height: 15,
            decoration: BoxDecoration(
              color: Color(0xFF1a1a2e),
              border: BoxBorder.all(
                color: Color(0xFF00ff88),
                style: BoxBorderStyle.rounded,
              ),
            ),
            padding: EdgeInsets.all(2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'COUNTER BENCHMARK',
                  style: TextStyle(
                    color: Color(0xFF00ff88),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '$_counter',
                  style: TextStyle(
                    color: Color(0xFFffffff),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Press any key to increment',
                  style: TextStyle(color: Color(0xFF6b7280)),
                ),
                SizedBox(height: 1),
                Text(
                  'Press Q to quit',
                  style: TextStyle(
                    color: Color(0xFF4b5563),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
