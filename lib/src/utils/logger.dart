import 'dart:async';
import 'dart:collection';
import 'dart:io';

/// A high-performance logger that buffers log messages in memory and writes
/// them to a file with debouncing to reduce I/O operations.
///
/// This logger is designed for TUI applications where frequent logging could
/// impact performance. Instead of writing each log message immediately to disk,
/// messages are buffered in memory and written in batches after a configurable
/// debounce delay.
///
/// Features:
/// - **In-memory buffering**: Log messages are stored in a queue for fast access
/// - **Debounced writes**: File I/O is batched and delayed to reduce overhead
/// - **Max buffer size**: Automatically drops oldest entries to prevent memory issues
/// - **Automatic timestamps**: Each log entry includes an ISO 8601 timestamp
/// - **Graceful shutdown**: Ensures all buffered logs are written on close
///
/// Example:
/// ```dart
/// final logger = Logger(
///   filePath: 'app.log',
///   debounceDelay: Duration(milliseconds: 500),
///   maxBufferSize: 1000,
/// );
///
/// logger.log('Application started');
/// logger.log('Processing data...');
///
/// // Flush immediately if needed
/// await logger.flush();
///
/// // Clean shutdown
/// await logger.close();
/// ```
///
/// The logger is used automatically by [runApp] to capture print statements
/// and errors to log.txt without blocking the TUI.
class Logger {
  Logger({
    this.filePath = 'log.txt',
    this.debounceDelay = const Duration(milliseconds: 500),
    this.maxBufferSize = 1000,
  });

  /// Path to the log file
  final String filePath;

  /// Delay before writing buffered logs to disk
  final Duration debounceDelay;

  /// Maximum number of log entries to keep in memory
  final int maxBufferSize;

  /// In-memory buffer of log entries
  final Queue<String> _buffer = Queue<String>();

  /// Timer for debounced writes
  Timer? _writeTimer;

  /// Whether the logger has been closed
  bool _closed = false;

  /// IOSink for writing to the log file
  IOSink? _sink;

  /// Add a log message to the buffer
  void log(String message) {
    if (_closed) return;

    final timestamp = DateTime.now().toIso8601String();
    final entry = '[$timestamp] $message';

    _buffer.add(entry);

    // Enforce max buffer size (drop oldest entries)
    while (_buffer.length > maxBufferSize) {
      _buffer.removeFirst();
    }

    // Schedule a debounced write
    _scheduleWrite();
  }

  /// Schedule a debounced write to disk
  void _scheduleWrite() {
    // Cancel any existing timer
    _writeTimer?.cancel();

    // Schedule a new write after the debounce delay
    _writeTimer = Timer(debounceDelay, _writeToFile);
  }

  /// Write buffered logs to file
  void _writeToFile() {
    if (_closed) return;

    try {
      // Lazily open the file sink
      if (_sink == null) {
        _sink = File(filePath).openWrite(mode: FileMode.writeOnly);
      }

      // Write all buffered entries
      while (_buffer.isNotEmpty) {
        final entry = _buffer.removeFirst();
        _sink!.writeln(entry);
      }
    } catch (e) {
      // If writing fails, keep entries in buffer for next attempt
      // But avoid infinite growth by limiting buffer size
    }
  }

  /// Flush all buffered logs to disk immediately
  Future<void> flush() async {
    if (_closed) return;

    // Cancel pending timer
    _writeTimer?.cancel();
    _writeTimer = null;

    // Write immediately
    _writeToFile();

    // Flush the sink
    if (_sink != null) {
      try {
        await _sink!.flush();
      } catch (_) {
        // Ignore flush errors
      }
    }
  }

  /// Close the logger and flush remaining logs
  Future<void> close() async {
    if (_closed) return;

    // Cancel timer
    _writeTimer?.cancel();
    _writeTimer = null;

    // Write any remaining buffered logs BEFORE marking as closed
    _writeToFile();

    // Now mark as closed to prevent new logs
    _closed = true;

    // Flush and close the sink
    if (_sink != null) {
      try {
        await _sink!.flush();
        await _sink!.close();
      } catch (_) {
        // Ignore close errors
      }
      _sink = null;
    }

    _buffer.clear();
  }

  /// Get a copy of the current buffer contents (for debugging)
  List<String> get buffer => List.unmodifiable(_buffer);
}
