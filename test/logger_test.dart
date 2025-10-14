import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

void main() {
  group('Logger', () {
    late Logger logger;
    late String testLogPath;

    setUp(() {
      testLogPath = 'test_log_${DateTime.now().millisecondsSinceEpoch}.txt';
      logger = Logger(
        filePath: testLogPath,
        debounceDelay: const Duration(milliseconds: 100),
        maxBufferSize: 100,
      );
    });

    tearDown(() async {
      await logger.close();
      // Clean up test log file
      final file = File(testLogPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('buffers log messages in memory', () {
      logger.log('First message');
      logger.log('Second message');
      logger.log('Third message');

      // Messages should be in buffer
      expect(logger.buffer.length, equals(3));
      expect(logger.buffer.any((entry) => entry.contains('First message')), isTrue);
      expect(logger.buffer.any((entry) => entry.contains('Second message')), isTrue);
      expect(logger.buffer.any((entry) => entry.contains('Third message')), isTrue);
    });

    test('writes to file after debounce delay', () async {
      logger.log('Test message');

      // Should not be written immediately
      final file = File(testLogPath);
      expect(await file.exists(), isFalse);

      // Wait for debounce delay + extra time
      await Future.delayed(const Duration(milliseconds: 200));

      // Should be written now
      expect(await file.exists(), isTrue);
      final contents = await file.readAsString();
      expect(contents, contains('Test message'));
    });

    test('enforces max buffer size', () {
      // Add more messages than the max buffer size
      for (int i = 0; i < 150; i++) {
        logger.log('Message $i');
      }

      // Buffer should not exceed max size
      expect(logger.buffer.length, lessThanOrEqualTo(100));

      // Oldest messages should be dropped
      expect(logger.buffer.any((entry) => entry.contains('Message 0')), isFalse);
      expect(logger.buffer.any((entry) => entry.contains('Message 149')), isTrue);
    });

    test('flush writes immediately', () async {
      logger.log('Immediate message');

      // Should not be written yet
      var file = File(testLogPath);
      expect(await file.exists(), isFalse);

      // Flush should write immediately
      await logger.flush();

      // Should be written now
      expect(await file.exists(), isTrue);
      final contents = await file.readAsString();
      expect(contents, contains('Immediate message'));
    });

    test('multiple logs are batched in single write', () async {
      logger.log('Message 1');
      logger.log('Message 2');
      logger.log('Message 3');

      await logger.flush();

      final file = File(testLogPath);
      final contents = await file.readAsString();

      // All messages should be in the file
      expect(contents, contains('Message 1'));
      expect(contents, contains('Message 2'));
      expect(contents, contains('Message 3'));
    });

    test('close flushes remaining logs', () async {
      logger.log('Final message');

      await logger.close();

      final file = File(testLogPath);
      expect(await file.exists(), isTrue);
      final contents = await file.readAsString();
      expect(contents, contains('Final message'));
    });

    test('includes timestamps in log entries', () {
      logger.log('Timestamped message');

      // Check that buffer entries have timestamps
      expect(logger.buffer.first, matches(r'\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'));
    });

    test('ignores log calls after close', () async {
      await logger.close();

      logger.log('Should be ignored');

      // Buffer should be empty
      expect(logger.buffer.length, equals(0));
    });
  });
}
