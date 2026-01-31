import 'dart:convert';
import 'dart:io';

import 'package:nocterm/nocterm.dart';

/// Benchmark app that measures frame time from build start to terminal flush.
/// Runs at maximum speed (no frame rate limiting) for 3 seconds.
void main() async {
  await runApp(const FrameTimeBenchmark());
}

class FrameTimeBenchmark extends StatefulComponent {
  const FrameTimeBenchmark({super.key});

  @override
  State<FrameTimeBenchmark> createState() => _FrameTimeBenchmarkState();
}

class _FrameTimeBenchmarkState extends State<FrameTimeBenchmark> {
  int _counter = 0;
  final List<int> _totalFrameTimesUs = [];
  final List<int> _buildTimesUs = [];
  final List<int> _layoutTimesUs = [];
  final List<int> _paintTimesUs = [];
  final Stopwatch _stopwatch = Stopwatch();
  bool _running = true;
  bool _benchmarkStarted = false;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();

    // Disable frame rate limiting to measure raw frame times
    SchedulerBinding.instance.enableFrameRateLimiting = false;

    // Register frame timing callback to capture per-frame breakdown
    SchedulerBinding.instance.addFrameTimingCallback(_onFrameTiming);

    // Start benchmark after first frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _benchmarkStarted = true;
      _scheduleNextFrame();
    });
  }

  void _onFrameTiming(FrameTiming timing) {
    if (!_benchmarkStarted || !_running) return;

    _totalFrameTimesUs.add(timing.totalDuration.inMicroseconds);
    _buildTimesUs.add(timing.buildDuration.inMicroseconds);
    _layoutTimesUs.add(timing.layoutDuration.inMicroseconds);
    _paintTimesUs.add(timing.paintDuration.inMicroseconds);
  }

  void _scheduleNextFrame() {
    if (!_running) return;

    // Stop after 3 seconds (enough samples, faster benchmark)
    if (_stopwatch.elapsedMilliseconds > 3000) {
      _running = false;
      _outputResults();
      Future.delayed(const Duration(milliseconds: 50), () {
        shutdownApp();
      });
      return;
    }

    // Trigger state change to force a new frame
    setState(() {
      _counter++;
    });

    // Schedule next frame immediately
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduleNextFrame();
    });
  }

  void _outputResults() {
    final elapsedMs = _stopwatch.elapsedMilliseconds;
    final frameCount = _totalFrameTimesUs.length;
    final fps = frameCount / (elapsedMs / 1000);

    final result = {
      'framework': 'nocterm',
      'test': 'frame_time',
      'durationMs': elapsedMs,
      'frameCount': frameCount,
      'fps': fps.round(),
      'totalFrameTime': _computeStats(
          _totalFrameTimesUs, 'Total frame (build+layout+paint+diff+flush)'),
      'buildTime': _computeStats(_buildTimesUs, 'Build phase'),
      'layoutTime': _computeStats(_layoutTimesUs, 'Layout phase'),
      'paintTime': _computeStats(_paintTimesUs, 'Paint phase'),
    };

    // Write results to file since stderr is mixed with terminal output
    File('/tmp/nocterm_frame_time_results.json')
        .writeAsStringSync(jsonEncode(result));
    stderr.writeln('Results written to /tmp/nocterm_frame_time_results.json');
  }

  Map<String, dynamic> _computeStats(List<int> times, String description) {
    if (times.isEmpty) return {'error': 'no samples'};

    final sorted = List<int>.from(times)..sort();
    final sum = sorted.reduce((a, b) => a + b);
    final mean = sum / sorted.length;
    final median = sorted[sorted.length ~/ 2];

    return {
      'description': description,
      'unit': 'microseconds',
      'samples': sorted.length,
      'mean': mean.round(),
      'median': median,
      'min': sorted.first,
      'max': sorted.last,
      'p95': sorted[(sorted.length * 0.95).floor()],
      'p99': sorted[(sorted.length * 0.99).floor()],
    };
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeFrameTimingCallback(_onFrameTiming);
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final elapsed = _stopwatch.elapsedMilliseconds;
    final frameCount = _totalFrameTimesUs.length;
    final currentFps =
        elapsed > 0 ? (frameCount / (elapsed / 1000)).toStringAsFixed(0) : '0';
    final avgFrameTime = frameCount > 0 && _totalFrameTimesUs.isNotEmpty
        ? (_totalFrameTimesUs.reduce((a, b) => a + b) / frameCount)
            .toStringAsFixed(0)
        : '0';

    return Container(
      decoration: BoxDecoration(color: Color(0xFF0f0f23)),
      child: Center(
        child: Container(
          width: 45,
          height: 12,
          decoration: BoxDecoration(
            color: Color(0xFF1a1a2e),
            border: BoxBorder.all(
              color: Color(0xFF00ff88),
              style: BoxBorderStyle.rounded,
            ),
          ),
          padding: EdgeInsets.all(1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'FRAME TIME BENCHMARK',
                style: TextStyle(
                  color: Color(0xFF00ff88),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 1),
              Text('Frames: $frameCount | FPS: $currentFps'),
              Text('Avg: ${avgFrameTime}us'),
              Text('Counter: $_counter'),
              SizedBox(height: 1),
              Text(
                '3 seconds, no FPS limit',
                style: TextStyle(color: Color(0xFF666666)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
