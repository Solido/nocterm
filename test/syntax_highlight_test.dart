import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart' hide isNotEmpty;

void main() {
  group('SyntaxHighlightText', () {
    test('visual development - Dart code', () async {
      await testNocterm(
        'dart code highlighting',
        (tester) async {
          await tester.pumpComponent(
            SyntaxHighlightText(
              code: '''
void main() {
  // This is a comment
  final message = "Hello, World!";
  print(message);

  for (int i = 0; i < 10; i++) {
    print(i);
  }
}
''',
              language: 'dart',
            ),
          );
        },
        debugPrintAfterPump: true,
      );
    });

    test('visual development - Python code', () async {
      await testNocterm(
        'python code highlighting',
        (tester) async {
          await tester.pumpComponent(
            SyntaxHighlightText(
              code: '''
def factorial(n):
    """Calculate factorial recursively"""
    if n <= 1:
        return 1
    return n * factorial(n - 1)

# Test the function
result = factorial(5)
print(f"Result: {result}")
''',
              language: 'python',
            ),
          );
        },
        debugPrintAfterPump: true,
      );
    });

    test('visual development - JavaScript code', () async {
      await testNocterm(
        'javascript code highlighting',
        (tester) async {
          await tester.pumpComponent(
            SyntaxHighlightText(
              code: '''
class Counter {
  constructor(initialValue = 0) {
    this.value = initialValue;
  }

  increment() {
    this.value++;
    return this.value;
  }
}

const counter = new Counter(10);
console.log(counter.increment());
''',
              language: 'javascript',
            ),
          );
        },
        debugPrintAfterPump: true,
      );
    });

    test('visual development - Rust code', () async {
      await testNocterm(
        'rust code highlighting',
        (tester) async {
          await tester.pumpComponent(
            SyntaxHighlightText(
              code: '''
fn main() {
    let numbers = vec![1, 2, 3, 4, 5];

    let sum: i32 = numbers.iter().sum();
    println!("Sum: {}", sum);

    match sum {
        0 => println!("Zero"),
        _ => println!("Non-zero: {}", sum),
    }
}
''',
              language: 'rust',
            ),
          );
        },
        debugPrintAfterPump: true,
      );
    });

    test('visual development - JSON code', () async {
      await testNocterm(
        'json highlighting',
        (tester) async {
          await tester.pumpComponent(
            SyntaxHighlightText(
              code: '''
{
  "name": "nocterm",
  "version": "0.1.0",
  "dependencies": {
    "highlighting": "^0.9.0"
  },
  "features": [
    "syntax highlighting",
    "190+ languages"
  ],
  "enabled": true,
  "count": 42
}
''',
              language: 'json',
            ),
          );
        },
        debugPrintAfterPump: true,
      );
    });

    test('visual development - Bash script', () async {
      await testNocterm(
        'bash script highlighting',
        (tester) async {
          await tester.pumpComponent(
            SyntaxHighlightText(
              code: r'''
#!/bin/bash

# Build and test script
set -e

echo "Building project..."
dart pub get

if [ "$1" == "test" ]; then
  echo "Running tests..."
  dart test
fi

echo "Done!"
''',
              language: 'bash',
            ),
          );
        },
        debugPrintAfterPump: true,
      );
    });

    test('renders correctly without language', () async {
      await testNocterm(
        'plain text rendering',
        (tester) async {
          const code = 'This is plain text without highlighting';
          await tester.pumpComponent(
            const SyntaxHighlightText(code: code),
          );

          expect(tester.terminalState, containsText(code));
        },
      );
    });

    test('renders correctly with unknown language', () async {
      await testNocterm(
        'unknown language fallback',
        (tester) async {
          const code = 'This is plain text';
          await tester.pumpComponent(
            const SyntaxHighlightText(
              code: code,
              language: 'unknown-language-xyz',
            ),
          );

          expect(tester.terminalState, containsText(code));
        },
      );
    });

    test('renders simple Dart code correctly', () async {
      await testNocterm(
        'simple dart rendering',
        (tester) async {
          const code = 'void main() {}';
          await tester.pumpComponent(
            const SyntaxHighlightText(
              code: code,
              language: 'dart',
            ),
          );

          expect(tester.terminalState, containsText('void'));
          expect(tester.terminalState, containsText('main'));
        },
      );
    });

    test('handles empty code', () async {
      await testNocterm(
        'empty code handling',
        (tester) async {
          await tester.pumpComponent(
            const SyntaxHighlightText(
              code: '',
              language: 'dart',
            ),
          );
          // Should not crash
        },
      );
    });

    test('custom theme - visual test', () async {
      await testNocterm(
        'custom theme',
        (tester) async {
          // Create a custom theme with different colors
          const customTheme = SyntaxHighlightTheme(
            keyword: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            string: TextStyle(color: Colors.yellow),
            comment: TextStyle(color: Colors.blue, fontStyle: FontStyle.italic),
            number: TextStyle(color: Colors.magenta),
          );

          await tester.pumpComponent(
            const SyntaxHighlightText(
              code: '''
void main() {
  // Custom colors!
  print("Hello");
  int x = 42;
}
''',
              language: 'dart',
              theme: customTheme,
            ),
          );
        },
        debugPrintAfterPump: true,
      );
    });

    test('multiline code with proper formatting', () async {
      await testNocterm(
        'multiline formatting',
        (tester) async {
          const code = '''
class Example {
  final String name;

  Example(this.name);
}
''';
          await tester.pumpComponent(
            const SyntaxHighlightText(
              code: code,
              language: 'dart',
            ),
          );

          expect(tester.terminalState, containsText('class'));
          expect(tester.terminalState, containsText('Example'));
          expect(tester.terminalState, containsText('String'));
        },
      );
    });

    test('available languages list is not empty', () {
      final languages = SyntaxHighlightText.availableLanguages;
      expect(languages, isNotEmpty);
      expect(languages, contains('dart'));
      expect(languages, contains('python'));
      expect(languages, contains('javascript'));
    });

    test('language support check', () {
      expect(SyntaxHighlightText.isLanguageSupported('dart'), isTrue);
      expect(SyntaxHighlightText.isLanguageSupported('python'), isTrue);
      expect(SyntaxHighlightText.isLanguageSupported('unknown-xyz'), isFalse);
    });

    test('visual comparison - multiple languages side by side', () async {
      await testNocterm(
        'multiple languages comparison',
        (tester) async {
          await tester.pumpComponent(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Dart:', style: TextStyle(fontWeight: FontWeight.bold)),
                SyntaxHighlightText(
                  code: 'final x = 42;',
                  language: 'dart',
                ),
                SizedBox(height: 1),
                Text('Python:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SyntaxHighlightText(
                  code: 'x = 42',
                  language: 'python',
                ),
                SizedBox(height: 1),
                Text('JavaScript:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SyntaxHighlightText(
                  code: 'const x = 42;',
                  language: 'javascript',
                ),
              ],
            ),
          );
        },
        debugPrintAfterPump: true,
      );
    });
  });

  group('SyntaxHighlightTheme', () {
    test('terminal theme has proper defaults', () {
      final theme = SyntaxHighlightTheme.terminal();

      expect(theme.keyword, isNotNull);
      expect(theme.string, isNotNull);
      expect(theme.comment, isNotNull);
      expect(theme.number, isNotNull);
    });

    test('styleForClass returns correct style', () {
      final theme = SyntaxHighlightTheme.terminal();

      final keywordStyle = theme.styleForClass('keyword');
      expect(keywordStyle, equals(theme.keyword));

      final stringStyle = theme.styleForClass('string');
      expect(stringStyle, equals(theme.string));

      final unknownStyle = theme.styleForClass('unknown-class-xyz');
      expect(unknownStyle, equals(theme.baseStyle));
    });

    test('styleForClass handles null and empty', () {
      final theme = SyntaxHighlightTheme.terminal();

      expect(theme.styleForClass(null), equals(theme.baseStyle));
      expect(theme.styleForClass(''), equals(theme.baseStyle));
    });

    test('styleForClass handles multiple classes', () {
      final theme = SyntaxHighlightTheme.terminal();

      // Should use the first matching class
      final style = theme.styleForClass('keyword string');
      expect(style, equals(theme.keyword));
    });
  });
}
