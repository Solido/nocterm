import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:nocterm/nocterm.dart';

/// Dashboard Benchmark
///
/// Tests: Complex UI updates, multiple animated elements, concurrent state changes
/// Features: Progress bars, live metrics, scrolling log
void main() async {
  await runApp(const DashboardApp());
}

class DashboardApp extends StatefulComponent {
  const DashboardApp({super.key});

  @override
  State<DashboardApp> createState() => _DashboardAppState();
}

class _DashboardAppState extends State<DashboardApp> {
  Timer? _updateTimer;
  final _random = math.Random();

  bool _firstFrameEmitted = false;
  late final Stopwatch _stopwatch;
  int _frameCount = 0;

  // Metrics
  double _cpuPercent = 45.0;
  double _memoryGb = 2.1;
  double _requestsPerSec = 1200.0;
  int _activeConnections = 42;

  // Progress bars
  final List<TaskProgress> _tasks = [
    TaskProgress('Build Project', 0.80),
    TaskProgress('Run Tests', 0.60),
    TaskProgress('Deploy Stage', 0.45),
    TaskProgress('Sync Database', 0.30),
    TaskProgress('Generate Docs', 0.15),
  ];

  // Log entries
  final List<LogEntry> _logs = [];
  int _logIdCounter = 0;

  // Uptime
  int _uptimeSeconds = 0;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _initializeLogs();
    _startUpdates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _initializeLogs() {
    _logs.addAll([
      LogEntry(_logIdCounter++, DateTime.now(), 'info', 'Dashboard started'),
      LogEntry(
          _logIdCounter++, DateTime.now(), 'info', 'Connected to metrics API'),
      LogEntry(_logIdCounter++, DateTime.now(), 'info', 'Monitoring active'),
    ]);
  }

  void _startUpdates() {
    _updateTimer = Timer.periodic(Duration(milliseconds: 100), (_) {
      if (!mounted) return;

      NoctermTimeline.startSync('dashboard_update');
      setState(() {
        _frameCount++;
        _uptimeSeconds = _stopwatch.elapsed.inSeconds;

        // Update metrics with random fluctuation
        _cpuPercent =
            (_cpuPercent + (_random.nextDouble() - 0.5) * 10).clamp(10.0, 95.0);
        _memoryGb =
            (_memoryGb + (_random.nextDouble() - 0.5) * 0.2).clamp(1.0, 8.0);
        _requestsPerSec = (_requestsPerSec + (_random.nextDouble() - 0.5) * 200)
            .clamp(500.0, 3000.0);
        _activeConnections =
            (_activeConnections + (_random.nextInt(5) - 2)).clamp(10, 100);

        // Update progress bars
        for (var task in _tasks) {
          if (task.progress < 1.0) {
            task.progress =
                (task.progress + _random.nextDouble() * 0.02).clamp(0.0, 1.0);
          } else {
            // Reset completed tasks
            task.progress = 0.0;
          }
        }

        // Add log entry occasionally
        if (_frameCount % 30 == 0) {
          final messages = [
            'Request processed successfully',
            'Cache refreshed',
            'Connection established',
            'Health check passed',
            'Metrics updated',
            'Task completed',
          ];
          final levels = ['info', 'info', 'info', 'warn', 'debug'];
          _logs.add(LogEntry(
            _logIdCounter++,
            DateTime.now(),
            levels[_random.nextInt(levels.length)],
            messages[_random.nextInt(messages.length)],
          ));
          if (_logs.length > 50) {
            _logs.removeAt(0);
          }
        }
      });
      NoctermTimeline.finishSync();

      // Emit frame timing
      final timeMs = _stopwatch.elapsedMicroseconds / 1000;
      stderr.writeln(jsonEncode({
        'event': 'frame',
        'timeMs': timeMs,
        'frameCount': _frameCount,
      }));
    });
  }

  void _emitFirstFrame() {
    if (!_firstFrameEmitted) {
      _firstFrameEmitted = true;
      final startupMs = _stopwatch.elapsedMicroseconds / 1000;
      stderr.writeln(jsonEncode({'event': 'first_frame', 'timeMs': startupMs}));
    }
  }

  String _formatUptime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
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
        decoration: BoxDecoration(color: Color(0xFF0d1117)),
        child: Column(
          children: [
            _buildHeader(),
            _buildMetricsRow(),
            Expanded(
              child: Row(
                children: [
                  // Progress bars panel
                  Expanded(
                    flex: 1,
                    child: _buildProgressPanel(),
                  ),
                  // Log panel
                  Expanded(
                    flex: 1,
                    child: _buildLogPanel(),
                  ),
                ],
              ),
            ),
            _buildStatusBar(),
          ],
        ),
      ),
    );
  }

  Component _buildHeader() {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: Color(0xFF161b22),
        border: BoxBorder(bottom: BorderSide(color: Color(0xFF30363d))),
      ),
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text('◆ ', style: TextStyle(color: Color(0xFF58a6ff))),
            Text('Dashboard',
                style: TextStyle(
                    color: Color(0xFFf0f6fc), fontWeight: FontWeight.bold)),
            Text(' Benchmark', style: TextStyle(color: Color(0xFF8b949e))),
          ]),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: Color(0xFF238636)),
            child: Text(' RUNNING ',
                style: TextStyle(
                    color: Color(0xFFffffff), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Component _buildMetricsRow() {
    return Container(
      height: 3,
      padding: EdgeInsets.symmetric(horizontal: 1, vertical: 0),
      decoration: BoxDecoration(
        color: Color(0xFF161b22),
        border: BoxBorder(bottom: BorderSide(color: Color(0xFF30363d))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMetric('CPU', '${_cpuPercent.toStringAsFixed(0)}%',
              _getMetricColor(_cpuPercent / 100)),
          _buildMetric(
              'MEM', '${_memoryGb.toStringAsFixed(1)}GB', Color(0xFFa371f7)),
          _buildMetric(
              'REQ',
              '${(_requestsPerSec / 1000).toStringAsFixed(1)}k/s',
              Color(0xFF58a6ff)),
          _buildMetric('CONN', '$_activeConnections', Color(0xFF3fb950)),
        ],
      ),
    );
  }

  Component _buildMetric(String label, String value, Color color) {
    return Row(
      children: [
        Text('$label: ', style: TextStyle(color: Color(0xFF8b949e))),
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Color _getMetricColor(double value) {
    if (value < 0.5) return Color(0xFF3fb950);
    if (value < 0.8) return Color(0xFFd29922);
    return Color(0xFFf85149);
  }

  Component _buildProgressPanel() {
    return Container(
      decoration: BoxDecoration(
        border: BoxBorder(right: BorderSide(color: Color(0xFF30363d))),
      ),
      padding: EdgeInsets.all(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tasks',
              style: TextStyle(
                  color: Color(0xFFf0f6fc), fontWeight: FontWeight.bold)),
          SizedBox(height: 1),
          for (var task in _tasks) _buildProgressBar(task),
        ],
      ),
    );
  }

  Component _buildProgressBar(TaskProgress task) {
    final percentage = (task.progress * 100).toInt();
    return Container(
      height: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(task.name, style: TextStyle(color: Color(0xFFc9d1d9))),
              Text('$percentage%', style: TextStyle(color: Color(0xFF8b949e))),
            ],
          ),
          ProgressBar(
            value: task.progress,
            valueColor: _getProgressColor(task.progress),
            backgroundColor: Color(0xFF21262d),
            fillCharacter: '█',
            emptyCharacter: '░',
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double value) {
    if (value < 0.3) return Color(0xFFf85149);
    if (value < 0.7) return Color(0xFFd29922);
    return Color(0xFF3fb950);
  }

  Component _buildLogPanel() {
    return Container(
      padding: EdgeInsets.all(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Log',
                  style: TextStyle(
                      color: Color(0xFFf0f6fc), fontWeight: FontWeight.bold)),
              Text('${_logs.length} entries',
                  style: TextStyle(color: Color(0xFF8b949e))),
            ],
          ),
          SizedBox(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _logs.length,
              reverse: true,
              itemExtent: 1,
              lazy: true,
              itemBuilder: (context, index) {
                final log = _logs[_logs.length - 1 - index];
                return _buildLogEntry(log);
              },
            ),
          ),
        ],
      ),
    );
  }

  Component _buildLogEntry(LogEntry log) {
    final timeStr = '${log.timestamp.hour.toString().padLeft(2, '0')}:'
        '${log.timestamp.minute.toString().padLeft(2, '0')}:'
        '${log.timestamp.second.toString().padLeft(2, '0')}';

    Color levelColor;
    switch (log.level) {
      case 'warn':
        levelColor = Color(0xFFd29922);
        break;
      case 'error':
        levelColor = Color(0xFFf85149);
        break;
      case 'debug':
        levelColor = Color(0xFF8b949e);
        break;
      default:
        levelColor = Color(0xFF58a6ff);
    }

    return Row(
      children: [
        Text('[$timeStr] ', style: TextStyle(color: Color(0xFF484f58))),
        Text('[${log.level.toUpperCase().padRight(5)}] ',
            style: TextStyle(color: levelColor)),
        Expanded(
          child: Text(log.message, style: TextStyle(color: Color(0xFFc9d1d9))),
        ),
      ],
    );
  }

  Component _buildStatusBar() {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: Color(0xFF161b22),
        border: BoxBorder(top: BorderSide(color: Color(0xFF30363d))),
      ),
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Running for ${_formatUptime(_uptimeSeconds)}',
              style: TextStyle(color: Color(0xFF8b949e))),
          Row(children: [
            Text('Frame: $_frameCount',
                style: TextStyle(color: Color(0xFF484f58))),
            SizedBox(width: 2),
            Text('[Q] Quit', style: TextStyle(color: Color(0xFF484f58))),
          ]),
        ],
      ),
    );
  }
}

class TaskProgress {
  final String name;
  double progress;
  TaskProgress(this.name, this.progress);
}

class LogEntry {
  final int id;
  final DateTime timestamp;
  final String level;
  final String message;
  LogEntry(this.id, this.timestamp, this.level, this.message);
}
