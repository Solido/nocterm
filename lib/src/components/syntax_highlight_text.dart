import 'package:highlighting/highlighting.dart';
import 'package:highlighting/languages/all.dart' as languages;
import 'package:nocterm/nocterm.dart';
import 'rich_text.dart';

/// A widget that displays syntax-highlighted code.
///
/// This widget uses the highlighting package to parse code and apply
/// syntax highlighting based on the specified language. It supports
/// over 190 programming languages including Dart, Python, JavaScript,
/// Java, C++, and many more.
///
/// Example:
/// ```dart
/// SyntaxHighlightText(
///   code: '''
///   void main() {
///     print("Hello, World!");
///   }
///   ''',
///   language: 'dart',
/// )
/// ```
///
/// Available languages can be found in the highlighting package documentation.
/// Common languages include: 'dart', 'python', 'javascript', 'java', 'cpp',
/// 'rust', 'go', 'bash', 'json', 'yaml', 'markdown', etc.
class SyntaxHighlightText extends StatelessComponent {
  /// Creates a syntax-highlighted text widget.
  ///
  /// The [code] parameter is the source code to highlight.
  /// The [language] parameter specifies the programming language for syntax
  /// highlighting. If null, no highlighting is applied.
  const SyntaxHighlightText({
    required this.code,
    this.language,
    this.theme,
    this.textAlign = TextAlign.left,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.maxLines,
    super.key,
  });

  /// The source code to display.
  final String code;

  /// The programming language for syntax highlighting.
  ///
  /// Examples: 'dart', 'python', 'javascript', 'java', 'cpp', 'rust', etc.
  /// If null, the code will be displayed without syntax highlighting.
  final String? language;

  /// The theme to use for syntax highlighting.
  ///
  /// If null, [SyntaxHighlightTheme.terminal] is used.
  final SyntaxHighlightTheme? theme;

  /// How the text should be aligned horizontally.
  final TextAlign textAlign;

  /// Whether the text should break at soft line breaks.
  final bool softWrap;

  /// How visual overflow should be handled.
  final TextOverflow overflow;

  /// An optional maximum number of lines for the text to span.
  final int? maxLines;

  // Static initialization flag
  static bool _languagesRegistered = false;

  /// Registers all available languages with the highlighting package.
  ///
  /// This is called automatically when the widget is first built.
  static void _registerLanguages() {
    if (_languagesRegistered) return;

    // Register all available languages
    // The 'all' import provides a comprehensive set of language definitions
    for (final lang in languages.allLanguages.values) {
      highlight.registerLanguage(lang);
    }

    _languagesRegistered = true;
  }

  @override
  Component build(BuildContext context) {
    // Ensure languages are registered
    _registerLanguages();

    final effectiveTheme = theme ?? SyntaxHighlightTheme.terminal();

    // If no language is specified, display as plain text
    if (language == null || language!.isEmpty) {
      return RichText(
        text: TextSpan(text: code, style: effectiveTheme.baseStyle),
        textAlign: textAlign,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
      );
    }

    // Parse the code with syntax highlighting
    Result? result;
    try {
      // Use a local variable to satisfy the type checker
      final lang = language!;
      result = highlight.parse(code, languageId: lang);
      print('DEBUG: Parsed language=$lang, relevance=${result.relevance}, nodes=${result.nodes?.length}');
    } catch (e, stackTrace) {
      // If highlighting fails (e.g., unknown language), fall back to plain text
      print('ERROR: Syntax highlighting failed for language "$language": $e');
      print('Stacktrace: $stackTrace');
      return RichText(
        text: TextSpan(text: code, style: effectiveTheme.baseStyle),
        textAlign: textAlign,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
      );
    }

    // Convert the highlighting result to TextSpan tree
    final spans = _convertNodesToSpans(result.nodes, effectiveTheme);

    return RichText(
      text: TextSpan(children: spans, style: effectiveTheme.baseStyle),
      textAlign: textAlign,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
    );
  }

  /// Converts highlighting nodes to TextSpan objects.
  ///
  /// This recursively processes the node tree returned by the highlighting
  /// package and converts it to nocterm's TextSpan structure with appropriate
  /// styling applied.
  ///
  /// The [parentClassName] parameter is used to pass down the className from
  /// parent nodes, since the highlighting package structure has className on
  /// parent nodes but actual text values on child nodes.
  List<InlineSpan> _convertNodesToSpans(
    List<Node>? nodes,
    SyntaxHighlightTheme theme, {
    String? parentClassName,
  }) {
    if (nodes == null || nodes.isEmpty) {
      return [];
    }

    final spans = <InlineSpan>[];

    for (final node in nodes) {
      final children = node.children;
      if (children.isNotEmpty) {
        // Node has children - recurse with this node's className
        final className = node.className;
        final childSpans = _convertNodesToSpans(
          children,
          theme,
          parentClassName: className ?? parentClassName,
        );

        if (className != null && className.isNotEmpty) {
          // Wrap children with styled span
          spans.add(
            TextSpan(
              children: childSpans,
              style: theme.styleForClass(className),
            ),
          );
        } else {
          // No class, just add children directly
          spans.addAll(childSpans);
        }
      } else if (node.value != null && node.value!.isNotEmpty) {
        // Leaf node with text content
        // Use the node's className if it has one, otherwise use parent's
        final effectiveClassName = node.className ?? parentClassName;
        spans.add(
          TextSpan(
            text: node.value,
            style: theme.styleForClass(effectiveClassName),
          ),
        );
      }
    }

    return spans;
  }

  /// Returns a list of all available language IDs.
  ///
  /// This can be used to validate language inputs or provide language selection.
  static List<String> get availableLanguages {
    _registerLanguages();
    return languages.allLanguages.keys.toList()..sort();
  }

  /// Checks if a language is supported.
  ///
  /// Returns true if the [languageId] is available for syntax highlighting.
  static bool isLanguageSupported(String languageId) {
    _registerLanguages();
    return languages.allLanguages.containsKey(languageId);
  }
}
