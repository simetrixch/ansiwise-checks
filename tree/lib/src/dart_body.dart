/// Where a Dart declaration's BODY begins and ends, counted over code rather than over text.
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

/// What may stand between a parameter list and the body it belongs to, before an initializer list
/// or the body's own opening.
final RegExp _bodyMarkers = RegExp(r'\s*(?:async\*?|sync\*)?\s*');

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
