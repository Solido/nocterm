import 'package:nocterm/nocterm.dart';

/// Theme for syntax highlighting that maps token types to text styles.
///
/// This class defines the visual appearance of different syntax elements
/// like keywords, strings, comments, etc. when rendering code in a terminal.
class SyntaxHighlightTheme {
  const SyntaxHighlightTheme({
    this.baseStyle,
    this.keyword,
    this.builtIn,
    this.type,
    this.literal,
    this.number,
    this.regexp,
    this.string,
    this.subst,
    this.symbol,
    this.className,
    this.function,
    this.title,
    this.params,
    this.comment,
    this.doctag,
    this.meta,
    this.metaKeyword,
    this.metaString,
    this.section,
    this.tag,
    this.name,
    this.attr,
    this.attribute,
    this.variable,
    this.bulletListMarker,
    this.code,
    this.emphasis,
    this.strong,
    this.formula,
    this.link,
    this.quote,
    this.selectorTag,
    this.selectorId,
    this.selectorClass,
    this.selectorAttr,
    this.selectorPseudo,
    this.templateTag,
    this.templateVariable,
    this.addition,
    this.deletion,
  });

  /// Creates a default theme optimized for terminal display.
  ///
  /// This theme uses colors that work well on dark terminal backgrounds
  /// and follows common syntax highlighting conventions.
  factory SyntaxHighlightTheme.terminal() {
    return const SyntaxHighlightTheme(
      baseStyle: TextStyle(color: Colors.white),

      // Keywords (if, else, class, def, etc.)
      keyword: TextStyle(
        color: Colors.magenta,
        fontWeight: FontWeight.bold,
      ),

      // Built-in types and functions
      builtIn: TextStyle(
        color: Colors.cyan,
        fontWeight: FontWeight.bold,
      ),

      // Type names
      type: TextStyle(
        color: Colors.cyan,
      ),

      // Literals (true, false, null, etc.)
      literal: TextStyle(
        color: Colors.brightMagenta,
      ),

      // Numbers
      number: TextStyle(
        color: Colors.brightYellow,
      ),

      // Regular expressions
      regexp: TextStyle(
        color: Colors.brightRed,
      ),

      // Strings
      string: TextStyle(
        color: Colors.green,
      ),

      // String substitution/interpolation
      subst: TextStyle(
        color: Colors.brightGreen,
      ),

      // Symbols
      symbol: TextStyle(
        color: Colors.brightCyan,
      ),

      // Class names
      className: TextStyle(
        color: Colors.yellow,
        fontWeight: FontWeight.bold,
      ),

      // Function names
      function: TextStyle(
        color: Colors.blue,
      ),

      // Titles (section headers, etc.)
      title: TextStyle(
        color: Colors.brightBlue,
        fontWeight: FontWeight.bold,
      ),

      // Function parameters
      params: TextStyle(
        color: Colors.white,
      ),

      // Comments
      comment: TextStyle(
        color: Colors.grey,
        fontStyle: FontStyle.italic,
      ),

      // Documentation tags (@param, @return, etc.)
      doctag: TextStyle(
        color: Colors.brightBlack,
        fontWeight: FontWeight.bold,
      ),

      // Meta information
      meta: TextStyle(
        color: Colors.grey,
      ),

      // Meta keywords
      metaKeyword: TextStyle(
        color: Colors.magenta,
      ),

      // Meta strings
      metaString: TextStyle(
        color: Colors.green,
      ),

      // Section headers
      section: TextStyle(
        color: Colors.yellow,
        fontWeight: FontWeight.bold,
      ),

      // HTML/XML tags
      tag: TextStyle(
        color: Colors.red,
      ),

      // Tag names
      name: TextStyle(
        color: Colors.brightBlue,
      ),

      // Attributes (short form)
      attr: TextStyle(
        color: Colors.cyan,
      ),

      // Attributes (long form)
      attribute: TextStyle(
        color: Colors.cyan,
      ),

      // Variables
      variable: TextStyle(
        color: Colors.brightCyan,
      ),

      // Bullet points in lists
      bulletListMarker: TextStyle(
        color: Colors.white,
      ),

      // Code blocks
      code: TextStyle(
        color: Colors.yellow,
      ),

      // Emphasis (italic)
      emphasis: TextStyle(
        fontStyle: FontStyle.italic,
      ),

      // Strong (bold)
      strong: TextStyle(
        fontWeight: FontWeight.bold,
      ),

      // Mathematical formulas
      formula: TextStyle(
        color: Colors.brightYellow,
      ),

      // Links
      link: TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),

      // Quotes
      quote: TextStyle(
        color: Colors.grey,
        fontStyle: FontStyle.italic,
      ),

      // CSS selector tags
      selectorTag: TextStyle(
        color: Colors.red,
      ),

      // CSS selector IDs
      selectorId: TextStyle(
        color: Colors.yellow,
      ),

      // CSS selector classes
      selectorClass: TextStyle(
        color: Colors.cyan,
      ),

      // CSS selector attributes
      selectorAttr: TextStyle(
        color: Colors.green,
      ),

      // CSS selector pseudo-classes
      selectorPseudo: TextStyle(
        color: Colors.magenta,
      ),

      // Template tags
      templateTag: TextStyle(
        color: Colors.magenta,
      ),

      // Template variables
      templateVariable: TextStyle(
        color: Colors.brightCyan,
      ),

      // Additions (diff)
      addition: TextStyle(
        color: Colors.green,
        backgroundColor: Colors.black,
      ),

      // Deletions (diff)
      deletion: TextStyle(
        color: Colors.red,
        backgroundColor: Colors.black,
      ),
    );
  }

  final TextStyle? baseStyle;
  final TextStyle? keyword;
  final TextStyle? builtIn;
  final TextStyle? type;
  final TextStyle? literal;
  final TextStyle? number;
  final TextStyle? regexp;
  final TextStyle? string;
  final TextStyle? subst;
  final TextStyle? symbol;
  final TextStyle? className;
  final TextStyle? function;
  final TextStyle? title;
  final TextStyle? params;
  final TextStyle? comment;
  final TextStyle? doctag;
  final TextStyle? meta;
  final TextStyle? metaKeyword;
  final TextStyle? metaString;
  final TextStyle? section;
  final TextStyle? tag;
  final TextStyle? name;
  final TextStyle? attr;
  final TextStyle? attribute;
  final TextStyle? variable;
  final TextStyle? bulletListMarker;
  final TextStyle? code;
  final TextStyle? emphasis;
  final TextStyle? strong;
  final TextStyle? formula;
  final TextStyle? link;
  final TextStyle? quote;
  final TextStyle? selectorTag;
  final TextStyle? selectorId;
  final TextStyle? selectorClass;
  final TextStyle? selectorAttr;
  final TextStyle? selectorPseudo;
  final TextStyle? templateTag;
  final TextStyle? templateVariable;
  final TextStyle? addition;
  final TextStyle? deletion;

  /// Returns the style for a given token class name.
  ///
  /// The [className] should match one of the HighlightJS token classes.
  /// Returns [baseStyle] if no specific style is defined for the class.
  TextStyle? styleForClass(String? className) {
    if (className == null || className.isEmpty) {
      return baseStyle;
    }

    // Handle multiple classes (space-separated)
    final classes = className.split(' ');

    // Use the first matching class
    for (final cls in classes) {
      final style = _getStyleForSingleClass(cls);
      if (style != null) {
        return style;
      }
    }

    return baseStyle;
  }

  TextStyle? _getStyleForSingleClass(String className) {
    switch (className) {
      case 'keyword':
        return keyword;
      case 'built_in':
        return builtIn;
      case 'type':
        return type;
      case 'literal':
        return literal;
      case 'number':
        return number;
      case 'regexp':
        return regexp;
      case 'string':
        return string;
      case 'subst':
        return subst;
      case 'symbol':
        return symbol;
      case 'class':
        return this.className;
      case 'className':
        return this.className;
      case 'function':
        return function;
      case 'title':
        return title;
      case 'params':
        return params;
      case 'comment':
        return comment;
      case 'doctag':
        return doctag;
      case 'meta':
        return meta;
      case 'meta-keyword':
        return metaKeyword;
      case 'meta-string':
        return metaString;
      case 'section':
        return section;
      case 'tag':
        return tag;
      case 'name':
        return name;
      case 'attr':
        return attr;
      case 'attribute':
        return attribute;
      case 'variable':
        return variable;
      case 'bullet':
        return bulletListMarker;
      case 'code':
        return code;
      case 'emphasis':
        return emphasis;
      case 'strong':
        return strong;
      case 'formula':
        return formula;
      case 'link':
        return link;
      case 'quote':
        return quote;
      case 'selector-tag':
        return selectorTag;
      case 'selector-id':
        return selectorId;
      case 'selector-class':
        return selectorClass;
      case 'selector-attr':
        return selectorAttr;
      case 'selector-pseudo':
        return selectorPseudo;
      case 'template-tag':
        return templateTag;
      case 'template-variable':
        return templateVariable;
      case 'addition':
        return addition;
      case 'deletion':
        return deletion;
      default:
        return null;
    }
  }
}
