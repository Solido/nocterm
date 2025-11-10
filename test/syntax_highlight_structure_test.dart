import 'package:highlighting/highlighting.dart';
import 'package:highlighting/languages/dart.dart' as dartLang;
import 'package:test/test.dart';

void main() {
  test('understand node structure', () {
    highlight.registerLanguage(dartLang.dart);

    final code = 'void main() {}';
    final result = highlight.parse(code, languageId: 'dart');

    print('\n=== Detailed Node Structure ===');
    for (final node in result.nodes!) {
      print('Node:');
      print('  className: ${node.className}');
      print('  value: ${node.value}');
      print('  hasChildren: ${node.children.isNotEmpty}');

      if (node.children.isNotEmpty) {
        print('  Children:');
        for (final child in node.children) {
          print('    - className: ${child.className}');
          print('      value: "${child.value}"');
          print('      hasChildren: ${child.children.isNotEmpty}');
        }
      }
    }
  });
}
