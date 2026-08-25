/// Where a Dart declaration, a class and a statement BEGIN and END, counted over code rather than
/// over text.
///
/// **Every offset here is an offset into the answer of `codeOf`.** A brace standing in a doc
/// comment or inside a string literal is not a brace of the program, and a region counted over one
/// is wrong in both directions: too far, and it reports the declaration written below; too short,
/// and it stops judging while the file is still counted among those that were judged. The second is
/// the worse one, because the only thing it changes on the screen is a number that now means less
/// than it says.
///
/// **A region whose end is not in the file is not a region.** Where a body does not close, nothing
/// is claimed — a region running to the end of the file is a guess, and a scan that makes one puts
/// every declaration written below under a body that ended somewhere above.
///
/// **Every scan that reads structure reads it HERE.** Two scans that each carried their own reader
/// would agree on the day they were written and drift afterwards — one learning a shape of
/// declaration the other never hears about — and the drift is silent, because a reader that stops
/// finding a body makes its scan come back clean.
library;

import 'argument_specs.dart';

/// A stretch of code, from [start] to just past [end].
final class CodeRegion {
  /// Records the region from [start] to [end], the second being the offset just past it.
  const CodeRegion({required this.start, required this.end});

  /// The offset the region begins at.
  final int start;

  /// The offset just past the region's last character.
  final int end;

  /// Whether [offset] sits inside this region.
  bool covers(int offset) => offset >= start && offset < end;
}

/// One declaration of a file: what it is called, what it is handed, and the body it runs.
final class DartDeclaration {
  /// Records the declaration called [name] that takes [parameters] and runs [body].
  const DartDeclaration({required this.name, required this.parameters, required this.body});

  /// What it is called.
  final String name;

  /// The parameter list, which stands OUTSIDE the body.
  ///
  /// A scan reading the body alone sees nothing of what the declaration was HANDED, and a value
  /// handed in is held exactly as one assigned inside is.
  final CodeRegion parameters;

  /// The body it runs, block or arrow alike.
  final CodeRegion body;
}

/// One class of a file: what it is called, and the region its body covers.
final class DartClass {
  /// Records the class called [name] whose body covers [body].
  const DartClass({required this.name, required this.body});

  /// What it is called.
  final String name;

  /// The region between its braces.
  final CodeRegion body;
}

/// Every declaration of [code] that has a parameter list and a body.
///
/// A name followed by a bracket pair is a declaration exactly where a BODY follows the pair: a call
/// is followed by `;`, by `,` or by a bracket, and never by `{`, by `=>` or by an initializer list.
/// The words Dart spells a control structure with are left out by name, because `if (…) {` has the
/// same shape and names no declaration.
List<DartDeclaration> declarationsIn(String code) => <DartDeclaration>[
  for (final RegExpMatch match in _nameThenBracket.allMatches(code))
    if (!_notADeclaration.contains(match.group(1)))
      if (bodyAfter(code, match.end - 1) case final CodeRegion body)
        DartDeclaration(
          name: match.group(1)!,
          parameters: CodeRegion(start: match.end - 1, end: body.start),
          body: body,
        ),
];

/// Every class of [code], and the region each one's body covers.
///
/// The header between the name and the body carries type arguments, what the class extends, what it
/// mixes in and what it implements, and none of those is written with a brace at bracket depth zero
/// — so the first such brace opens the body. A mixin application reaches its `;` first and declares
/// no body of its own, and a class whose body does not close claims no region at all.
List<DartClass> classesIn(String code) {
  final List<DartClass> classes = <DartClass>[];
  for (final RegExpMatch match in _classOpening.allMatches(code)) {
    final int? opening = _bodyBraceAfter(code, match.end);
    if (opening == null) {
      continue;
    }
    final int? end = endOfBlock(code, opening);
    if (end == null) {
      continue;
    }
    classes.add(
      DartClass(
        name: match.group(1)!,
        body: CodeRegion(start: opening, end: end),
      ),
    );
  }
  return classes;
}

/// The declarations of [declarations] that stand DIRECTLY in [region] rather than inside another
/// declaration written there.
///
/// A function declared inside a method body sits in the same class region as the method does, and
/// counting it as one of the class's own would pair the wrong bodies together.
List<DartDeclaration> directlyIn(CodeRegion region, List<DartDeclaration> declarations) =>
    <DartDeclaration>[
      for (final DartDeclaration declaration in declarations)
        if (region.covers(declaration.body.start))
          if (!declarations.any(
            (DartDeclaration other) =>
                !identical(other, declaration) && other.body.covers(declaration.body.start),
          ))
            declaration,
    ];

/// The offset of [token] in [expression] at bracket depth zero, from [from], or null where it
/// stands at no such place.
///
/// A `?` belonging to a nullable type, to `?.` or to `??` is not the `?` of a ternary, and neither
/// is a `:` of `::` or of a named argument inside a bracket. Both are stepped over here rather than
/// left to a pattern, because a call written across four lines carries several of each.
int? topLevelAt(String expression, String token, {int from = 0}) {
  int depth = 0;
  for (int i = from; i < expression.length; i++) {
    final String char = expression[i];
    if (char == '(' || char == '[' || char == '{') {
      depth++;
      continue;
    }
    if (char == ')' || char == ']' || char == '}') {
      depth--;
      continue;
    }
    if (depth != 0 || char != token) {
      continue;
    }
    if (token == '?') {
      final String next = i + 1 < expression.length ? expression[i + 1] : ' ';
      final String previous = i > 0 ? expression[i - 1] : ' ';
      if (next == '?' || next == '.' || next == '[' || previous == '?') {
        continue;
      }
    }
    return i;
  }
  return null;
}

/// The statement or block guarded by a condition that closes at [from], or null where none
/// follows.
CodeRegion? guardedAfter(String code, int from) {
  final int at = pastWhitespace(code, from);
  if (at >= code.length) {
    return null;
  }
  final int? end = code.startsWith('{', at) ? endOfBlock(code, at) : endOfExpression(code, at);
  return end == null ? null : CodeRegion(start: at, end: end);
}

/// An `if` and the bracket its condition opens with.
final RegExp ifOpening = RegExp(r'(?<![\w$])if\s*\(');

/// A `return` and the whitespace after it.
final RegExp returnOpening = RegExp(r'(?<![\w$])return\s+');

/// The body of the declaration whose parameter list opens at [openBracket], or null where it has
/// none or where its end is not in [code].
///
/// What may stand between the parameter list and the body is whitespace, the words a Dart function
/// marks its own kind with, and a constructor's initializer list; then the body is either a block
/// or an arrow expression, and each is read to its own end by counting brackets. A parameter list
/// followed by anything else belongs to a declaration that makes no call of its own — an interface
/// method, or a constructor redirecting to another.
CodeRegion? bodyAfter(String code, int openBracket) {
  final int afterParameters = openBracket + balancedFrom(code, openBracket).length;
  final int? opening = _bodyOpeningAfter(code, afterParameters);
  if (opening == null) {
    return null;
  }
  final int? end = code.startsWith('{', opening)
      ? endOfBlock(code, opening)
      : endOfExpression(code, opening);
  return end == null ? null : CodeRegion(start: opening, end: end);
}

/// The bracket whose OWN arguments [offset] stands among, or null where it stands in none.
///
/// Read backwards, so a nested bracket pair closes before it opens and the walk steps over it
/// whole. That is what keeps a declaration written as a local or as a field from being taken for a
/// parameter: nothing encloses it, so the walk reaches the start of the file and answers null.
int? enclosingBracket(String code, int offset) {
  int depth = 0;
  for (int i = offset - 1; i >= 0; i--) {
    final String char = code[i];
    if (char == ')') {
      depth++;
    } else if (char == '(') {
      if (depth == 0) {
        return i;
      }
      depth--;
    }
  }
  return null;
}

/// The offset just past the block that opens at [openBrace], or null where it does not close.
int? endOfBlock(String code, int openBrace) {
  int depth = 0;
  for (int i = openBrace; i < code.length; i++) {
    if (code[i] == '{') {
      depth++;
    } else if (code[i] == '}') {
      depth--;
      if (depth == 0) {
        return i + 1;
      }
    }
  }
  return null;
}

/// The offset just past the expression that begins at [from], or null where it does not end.
///
/// It ends at the semicolon that closes the declaration or the statement, and a semicolon inside a
/// bracket of the expression's own — a statement of a closure it hands somewhere — belongs to that
/// bracket.
int? endOfExpression(String code, int from) {
  int depth = 0;
  for (int i = from; i < code.length; i++) {
    final String char = code[i];
    if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      depth--;
    } else if (char == ';' && depth <= 0) {
      return i + 1;
    }
  }
  return null;
}

/// The offset of the first character from [from] that is not whitespace, or the end of [code].
int pastWhitespace(String code, int from) {
  int at = from;
  while (at < code.length && _whitespace.hasMatch(code[at])) {
    at++;
  }
  return at;
}

/// The offset the body opens at, reading from [from] — just past a parameter list — or null where
/// the declaration has no body.
int? _bodyOpeningAfter(String code, int from) {
  final int at = _bodyMarkers.matchAsPrefix(code, from)?.end ?? from;
  if (code.startsWith(':', at)) {
    return _bodyAfterInitializers(code, at + 1);
  }
  if (code.startsWith('{', at) || code.startsWith('=>', at)) {
    return at;
  }
  return null;
}

/// The offset the body opens at, for a constructor whose initializer list begins at [from], or
/// null where it has none.
///
/// The list is read with bracket depth, so an argument list or an index written inside it is
/// stepped over whole. A brace at depth zero is either a collection literal an initializer is
/// given or the body itself, and WHAT FOLLOWS ITS MATCH tells the two apart: after a literal the
/// list goes on — with a comma, an operator, or the `;` of a constructor that has no body — and
/// after the body nothing of the declaration is left. The preceding token cannot decide it,
/// because `const {…}` and `<String, String>{…}` end in different kinds of token and are both
/// literals.
int? _bodyAfterInitializers(String code, int from) {
  int depth = 0;
  for (int i = from; i < code.length; i++) {
    final String char = code[i];
    if (char == '(' || char == '[') {
      depth++;
    } else if (char == ')' || char == ']') {
      depth--;
    } else if (depth > 0) {
      continue;
    } else if (char == ';') {
      return null;
    } else if (char == '{') {
      final int? close = endOfBlock(code, i);
      if (close == null) {
        return null;
      }
      final int next = pastWhitespace(code, close);
      if (next >= code.length) {
        return i;
      }
      if (code[next] == '{') {
        return next;
      }
      if (!_initializerGoesOn.contains(code[next])) {
        return i;
      }
      i = next - 1;
    }
  }
  return null;
}

/// The offset of the brace that opens a class body, reading from [from] — just past the class name
/// — or null where the declaration has no body.
int? _bodyBraceAfter(String code, int from) {
  int depth = 0;
  for (int i = from; i < code.length; i++) {
    final String char = code[i];
    if (char == '(' || char == '[') {
      depth++;
    } else if (char == ')' || char == ']') {
      depth--;
    } else if (depth > 0) {
      continue;
    } else if (char == ';') {
      return null;
    } else if (char == '{') {
      return i;
    }
  }
  return null;
}

/// What may stand between a parameter list and the body it belongs to, before an initializer list
/// or the body's own opening.
final RegExp _bodyMarkers = RegExp(r'\s*(?:async\*?|sync\*)?\s*');

/// A class and the name it is given.
final RegExp _classOpening = RegExp(r'(?<![\w$])class\s+([a-zA-Z_$][\w$]*)');

/// A name followed by the bracket a parameter list would open with.
final RegExp _nameThenBracket = RegExp(r'(?<![\w$])([a-zA-Z_$][\w$]*)\s*\(');

/// The words that take a bracket and declare nothing.
const Set<String> _notADeclaration = <String>{
  'assert',
  'await',
  'case',
  'catch',
  'do',
  'else',
  'for',
  'if',
  'in',
  'is',
  'new',
  'on',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'when',
  'while',
  'yield',
};

/// One whitespace character.
final RegExp _whitespace = RegExp(r'\s');

/// What an initializer list goes on with after a collection literal one of its entries is given.
///
/// A comma or an operator continues the list, and `;` closes a constructor that has no body. A
/// body is followed by none of them: whatever stands after it belongs to the next declaration.
const Set<String> _initializerGoesOn = <String>{
  ',',
  '.',
  ';',
  '?',
  ':',
  '+',
  '-',
  '*',
  '/',
  '%',
  '=',
  '!',
  '<',
  '>',
  '&',
  '|',
  '^',
  '~',
};
