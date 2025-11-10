import 'package:highlighting/highlighting.dart';
import 'package:highlighting/languages/all.dart' as languages;
import 'package:test/test.dart';

void main() {
  test('debug highlighting package', () {
    // Register dart language
    for (final lang in languages.allLanguages.values) {
      highlight.registerLanguage(lang);
    }

    final code = '''
void main() {
  final message = "Hello, World!";
  print(message);
}
''';

    print('Parsing with language: dart');
    final result = highlight.parse(code, languageId: 'dart');

    print('\n=== Result ===');
    print('Language: ${result.language}');
    print('Relevance: ${result.relevance}');
    print('Nodes count: ${result.nodes?.length}');

    print('\n=== Node tree ===');
    _printNodes(result.nodes, 0);
  });
}

void _printNodes(List<Node>? nodes, int depth) {
  if (nodes == null) return;

  final indent = '  ' * depth;
  for (final node in nodes) {
    if (node.value != null && node.value!.isNotEmpty) {
      print('$indent- VALUE: "${node.value}" (class: ${node.className ?? "none"})');
    }
    if (node.children.isNotEmpty) {
      print('$indent- NODE (class: ${node.className ?? "none"}):');
      _printNodes(node.children, depth + 1);
    }
  }
}
