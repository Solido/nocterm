import 'dart:io';
import 'package:nocterm/nocterm.dart';

class LoggerDemoApp extends StatefulComponent {
  @override
  State<LoggerDemoApp> createState() => _LoggerDemoAppState();
}

class _LoggerDemoAppState extends State<LoggerDemoApp> {
  @override
  void initState() {
    super.initState();
    // Log some messages when the app starts
    print('App started at ${DateTime.now()}');
    print('This message should be buffered');
    print('Multiple messages will be batched');
    print('Logger uses debouncing for efficient I/O');
  }

  @override
  Component build(BuildContext context) {
    return const Column(
      children: [
        Text('Logger Demo'),
        Text('Check log.txt for output'),
        Text(''),
        Text('Logging complete - press Ctrl+C to exit'),
      ],
    );
  }
}

void main() async {
  // Run the app (which will use the new Logger)
  await runApp(LoggerDemoApp());

  // After app exits, verify log.txt was created
  final logFile = File('log.txt');
  if (await logFile.exists()) {
    final contents = await logFile.readAsString();
    stdout.writeln('\n=== Log file contents ===');
    stdout.writeln(contents);
    stdout.writeln('=== End of log ===\n');
  } else {
    stdout.writeln('Warning: log.txt was not created');
  }
}
