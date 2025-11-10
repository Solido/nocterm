import 'package:nocterm/nocterm.dart';

/// Demo showcasing the SyntaxHighlightText component with various programming languages.
void main() {
  runApp(const SyntaxHighlightDemo());
}

class SyntaxHighlightDemo extends StatefulComponent {
  const SyntaxHighlightDemo({super.key});

  @override
  State<SyntaxHighlightDemo> createState() => _SyntaxHighlightDemoState();
}

class _SyntaxHighlightDemoState extends State<SyntaxHighlightDemo> {
  int _selectedExample = 0;

  final List<CodeExample> _examples = [
    CodeExample(
      title: 'Dart - Hello World',
      language: 'dart',
      code: '''
void main() {
  // Print a greeting
  final message = "Hello, World!";
  print(message);

  // Demonstrate loops
  for (int i = 0; i < 5; i++) {
    print('Count: \$i');
  }
}
''',
    ),
    CodeExample(
      title: 'Python - Factorial Function',
      language: 'python',
      code: '''
def factorial(n):
    """Calculate factorial recursively"""
    if n <= 1:
        return 1
    return n * factorial(n - 1)

# Test the function
result = factorial(5)
print(f"Factorial of 5: {result}")
''',
    ),
    CodeExample(
      title: 'JavaScript - Counter Class',
      language: 'javascript',
      code: '''
class Counter {
  constructor(initialValue = 0) {
    this.value = initialValue;
  }

  increment() {
    this.value++;
    return this.value;
  }

  decrement() {
    this.value--;
    return this.value;
  }
}

const counter = new Counter(10);
console.log(counter.increment()); // 11
console.log(counter.decrement()); // 10
''',
    ),
    CodeExample(
      title: 'Rust - Vector Operations',
      language: 'rust',
      code: '''
fn main() {
    let numbers = vec![1, 2, 3, 4, 5];

    let sum: i32 = numbers.iter().sum();
    println!("Sum: {}", sum);

    let doubled: Vec<i32> = numbers
        .iter()
        .map(|x| x * 2)
        .collect();

    match sum {
        0 => println!("Zero"),
        _ => println!("Non-zero: {}", sum),
    }
}
''',
    ),
    CodeExample(
      title: 'JSON - Configuration File',
      language: 'json',
      code: '''
{
  "name": "nocterm",
  "version": "0.1.0",
  "description": "A Flutter-like framework for terminal UIs",
  "dependencies": {
    "highlighting": "^0.9.0",
    "markdown": "^7.2.0"
  },
  "features": [
    "syntax highlighting",
    "190+ languages",
    "terminal rendering"
  ],
  "enabled": true,
  "maxConnections": 100
}
''',
    ),
    CodeExample(
      title: 'Bash - Build Script',
      language: 'bash',
      code: r'''
#!/bin/bash

# Build and test script
set -e

PROJECT_DIR="$(pwd)"
echo "Building project in: $PROJECT_DIR"

# Install dependencies
echo "Installing dependencies..."
dart pub get

# Run tests
if [ "$1" == "test" ]; then
  echo "Running tests..."
  dart test
fi

# Build
echo "Building..."
dart compile exe bin/main.dart -o build/app

echo "Done!"
''',
    ),
    CodeExample(
      title: 'Go - HTTP Server',
      language: 'go',
      code: '''
package main

import (
    "fmt"
    "net/http"
)

func handler(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, "Hello, %s!", r.URL.Path[1:])
}

func main() {
    http.HandleFunc("/", handler)
    fmt.Println("Server starting on :8080")
    http.ListenAndServe(":8080", nil)
}
''',
    ),
    CodeExample(
      title: 'TypeScript - Generic Function',
      language: 'typescript',
      code: '''
interface Container<T> {
  value: T;
  getValue(): T;
}

class Box<T> implements Container<T> {
  constructor(public value: T) {}

  getValue(): T {
    return this.value;
  }

  map<U>(fn: (value: T) => U): Box<U> {
    return new Box(fn(this.value));
  }
}

const numberBox = new Box(42);
const stringBox = numberBox.map(n => n.toString());
console.log(stringBox.getValue()); // "42"
''',
    ),
    CodeExample(
      title: 'SQL - Database Query',
      language: 'sql',
      code: '''
-- Select users with recent activity
SELECT
    u.id,
    u.username,
    u.email,
    COUNT(a.id) as activity_count
FROM users u
LEFT JOIN activities a ON u.id = a.user_id
WHERE a.created_at > DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY u.id
HAVING activity_count > 5
ORDER BY activity_count DESC
LIMIT 10;
''',
    ),
    CodeExample(
      title: 'YAML - Docker Compose',
      language: 'yaml',
      code: '''
version: '3.8'

services:
  web:
    image: nginx:latest
    ports:
      - "80:80"
    volumes:
      - ./html:/usr/share/nginx/html
    environment:
      - NGINX_HOST=example.com
      - NGINX_PORT=80
    networks:
      - webnet

  db:
    image: postgres:14
    environment:
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: myapp
    volumes:
      - db-data:/var/lib/postgresql/data

volumes:
  db-data:

networks:
  webnet:
''',
    ),
  ];

  void _previousExample() {
    setState(() {
      _selectedExample = (_selectedExample - 1 + _examples.length) % _examples.length;
    });
  }

  void _nextExample() {
    setState(() {
      _selectedExample = (_selectedExample + 1) % _examples.length;
    });
  }

  @override
  Component build(BuildContext context) {
    final example = _examples[_selectedExample];

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.arrowUp ||
            event.logicalKey == LogicalKey.keyK) {
          _previousExample();
          return true;
        } else if (event.logicalKey == LogicalKey.arrowDown ||
            event.logicalKey == LogicalKey.keyJ) {
          _nextExample();
          return true;
        } else if (event.logicalKey == LogicalKey.keyQ) {
          shutdownApp();
          return true;
        } else if (event.character != null) {
          // Handle number keys 1-9, 0 for snippets
          final char = event.character!;
          if (char == '0') {
            setState(() {
              _selectedExample = 9; // 10th item (index 9)
            });
            return true;
          } else if (char.codeUnitAt(0) >= '1'.codeUnitAt(0) &&
              char.codeUnitAt(0) <= '9'.codeUnitAt(0)) {
            final index = int.parse(char) - 1;
            if (index < _examples.length) {
              setState(() {
                _selectedExample = index;
              });
              return true;
            }
          }
        }
        return false;
      },
      child: Container(
        decoration: BoxDecoration(
          border: BoxBorder.all(style: BoxBorderStyle.rounded),
        ),
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Colors.cyan,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Syntax Highlighting Demo',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Snippet ${_selectedExample + 1}/${_examples.length}',
                    style: TextStyle(color: Colors.black),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 1),

            // Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Text(
                '${_selectedExample + 1}. ${example.title}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.yellow,
                ),
              ),
            ),

            const SizedBox(height: 1),

            // Code display with border
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: BoxBorder.all(
                    style: BoxBorderStyle.solid,
                    color: Colors.grey,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    child: SyntaxHighlightText(
                      code: example.code,
                      language: example.language,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 1),

            // Instructions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: Colors.brightBlack,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Controls: ↑/K: Previous  ↓/J: Next  1-9,0: Jump to snippet  Q: Quit',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CodeExample {
  final String title;
  final String language;
  final String code;

  const CodeExample({
    required this.title,
    required this.language,
    required this.code,
  });
}
