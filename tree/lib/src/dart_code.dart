/// A Dart file's CODE, with everything that is only text taken out of the way.
///
/// **Whatever reads STRUCTURE reads it here first.** A bracket counted to its match, a block read
/// to its closing brace: a brace standing inside a comment or inside a string literal is not a
/// brace of the program, and counting one is not a small inaccuracy.
///
/// Three shapes say what it costs, and every one of them was measured. A doc comment quoting a
/// signature opens a region that runs on into the next function, so a call with nothing to pass is
/// reported and the only fix anybody can see is to delete the comment. An unmatched `{` inside a
/// shell fragment or a `RegExp` carries a region past the body it belongs to and swallows the
/// function written beside it, which is the same finding one hop further out. An unmatched `}`
/// closes a region early, so a call that really does drop something is never judged — while the
/// file is still counted among the files that were judged. The first two report a finding nobody
/// can fix; the third is the worse one, because it is silent and it corrupts the count as well.
///
/// This is a masker and not a parser. It decides where a comment and a string BEGIN and END and
/// nothing else, which is the whole of what a bracket count needs.
library;

/// [text] with every comment and the inside of every string literal replaced by spaces.
///
/// Nothing is added and nothing is removed, and every line terminator is kept where it stands. So
/// an offset into the answer is the same offset into [text], and `lineAt` gives the same line for
/// either — which is what lets a scan find a call in the answer and name it at its real line.
///
/// **A string's DELIMITERS are kept**, so what is left still reads as an expression: `'a)b'`
/// becomes `'   '` rather than five spaces, and the brackets around it are still counted the same
/// way. The code of a `$name` or a `${…}` interpolation is kept too, because it really is code and
/// its own braces really are balanced.
///
/// **Where the file is not Dart the mask stops rather than running on.** A string a line terminator
/// reaches before its closing quote is ended there — Dart has no such string, so what follows is
/// read as code again instead of the rest of the file being blanked away. A comment or a string
/// still open at the end of the file is blanked to the end, which is what it is.
String codeOf(String text) {
  final List<int> code = List<int>.of(text.codeUnits);
  final List<_OpenString> open = <_OpenString>[];
  int at = 0;
  while (at < code.length) {
    final _OpenString? inside = open.isEmpty ? null : open.last;
    at = inside == null || inside.braces > 0
        ? _readCode(code, at, open)
        : _readString(code, at, open);
  }
  return String.fromCharCodes(code);
}

/// One string literal standing open, and the interpolation standing open inside it.
final class _OpenString {
  _OpenString({required this.quote, required this.triple, required this.raw});

  /// The quote character it opened with.
  final int quote;

  /// Whether it opened with three of them.
  final bool triple;

  /// Whether it is a raw string, where a backslash escapes nothing and `$` interpolates nothing.
  final bool raw;

  /// How deep the braces of a `${…}` interpolation stand open inside it, and zero while the scan
  /// is in the string's own text. This is what tells the two apart, since the code of an
  /// interpolation may open a string of its own.
  int braces = 0;
}

/// Reads one character of code at [at], opening whatever it begins, and answers where to read next.
int _readCode(List<int> code, int at, List<_OpenString> open) {
  final int unit = code[at];
  if (unit == _slash && at + 1 < code.length) {
    if (code[at + 1] == _slash) {
      return _blankLineComment(code, at);
    }
    if (code[at + 1] == _star) {
      return _blankBlockComment(code, at);
    }
  }
  if (_opensString(code, at)) {
    return _openString(code, at, open);
  }
  if (open.isNotEmpty) {
    if (unit == _openBrace) {
      open.last.braces++;
    } else if (unit == _closeBrace) {
      open.last.braces--;
    }
  }
  return at + 1;
}

/// Reads one character of the string standing open, blanking it unless it ends the string or
/// begins an interpolation, and answers where to read next.
int _readString(List<int> code, int at, List<_OpenString> open) {
  final _OpenString inside = open.last;
  final int unit = code[at];
  if (unit == inside.quote && (!inside.triple || _tripleAt(code, at, inside.quote))) {
    open.removeLast();
    return at + (inside.triple ? 3 : 1);
  }
  if (!inside.triple && (unit == _newline || unit == _carriageReturn)) {
    // No Dart string carries a line terminator without three quotes, so this file is not Dart.
    // Ending the string here keeps the mask from swallowing everything below it.
    open.removeLast();
    return at;
  }
  if (!inside.raw && unit == _backslash && at + 1 < code.length) {
    _blank(code, at);
    _blank(code, at + 1);
    return at + 2;
  }
  if (!inside.raw && unit == _dollar) {
    return _readInterpolation(code, at, inside);
  }
  _blank(code, at);
  return at + 1;
}

/// Reads the interpolation that the `$` at [at] begins, and answers where to read next.
int _readInterpolation(List<int> code, int at, _OpenString inside) {
  if (at + 1 < code.length && code[at + 1] == _openBrace) {
    inside.braces = 1;
    return at + 2;
  }
  if (at + 1 < code.length && _startsIdentifier(code[at + 1])) {
    int end = at + 2;
    while (end < code.length && _continuesIdentifier(code[end])) {
      end++;
    }
    return end;
  }
  _blank(code, at);
  return at + 1;
}

/// Whether a string literal begins at [at], counting the `r` of a raw one as its beginning.
bool _opensString(List<int> code, int at) {
  if (code[at] == _singleQuote || code[at] == _doubleQuote) {
    return true;
  }
  if (code[at] != _lowerR || at + 1 >= code.length) {
    return false;
  }
  if (code[at + 1] != _singleQuote && code[at + 1] != _doubleQuote) {
    return false;
  }
  return at == 0 || !_continuesIdentifier(code[at - 1]);
}

/// Opens the string literal beginning at [at] and answers the offset just past its delimiter.
int _openString(List<int> code, int at, List<_OpenString> open) {
  final bool raw = code[at] == _lowerR;
  final int quote = raw ? at + 1 : at;
  final bool triple = _tripleAt(code, quote, code[quote]);
  open.add(_OpenString(quote: code[quote], triple: triple, raw: raw));
  return quote + (triple ? 3 : 1);
}

/// Blanks the line comment beginning at [at] and answers the offset of the line terminator ending
/// it, or the end of the file.
int _blankLineComment(List<int> code, int at) {
  int end = at;
  while (end < code.length && code[end] != _newline && code[end] != _carriageReturn) {
    code[end] = _space;
    end++;
  }
  return end;
}

/// Blanks the block comment beginning at [at] and answers the offset just past it.
///
/// Dart nests them, so the depth is counted rather than the first `*/` taken as the end.
int _blankBlockComment(List<int> code, int at) {
  int depth = 0;
  int end = at;
  while (end < code.length) {
    if (end + 1 < code.length && code[end] == _slash && code[end + 1] == _star) {
      depth++;
    } else if (end + 1 < code.length && code[end] == _star && code[end + 1] == _slash) {
      depth--;
    } else {
      _blank(code, end);
      end++;
      continue;
    }
    _blank(code, end);
    _blank(code, end + 1);
    end += 2;
    if (depth == 0) {
      return end;
    }
  }
  return end;
}

/// Replaces [at] with a space, leaving a line terminator where it stands so that the line a later
/// offset sits on is the line it sits on in the file.
void _blank(List<int> code, int at) {
  if (code[at] != _newline && code[at] != _carriageReturn) {
    code[at] = _space;
  }
}

/// Whether [quote] stands three times over at [at].
bool _tripleAt(List<int> code, int at, int quote) =>
    at + 2 < code.length && code[at + 1] == quote && code[at + 2] == quote;

/// Whether [unit] may begin a Dart identifier.
bool _startsIdentifier(int unit) =>
    unit == _underscore ||
    unit == _dollar ||
    (unit >= _lowerA && unit <= _lowerZ) ||
    (unit >= _upperA && unit <= _upperZ);

/// Whether [unit] may stand inside a Dart identifier.
bool _continuesIdentifier(int unit) => _startsIdentifier(unit) || (unit >= _zero && unit <= _nine);

const int _space = 0x20;
const int _newline = 0x0A;
const int _carriageReturn = 0x0D;
const int _doubleQuote = 0x22;
const int _dollar = 0x24;
const int _singleQuote = 0x27;
const int _star = 0x2A;
const int _slash = 0x2F;
const int _zero = 0x30;
const int _nine = 0x39;
const int _upperA = 0x41;
const int _upperZ = 0x5A;
const int _backslash = 0x5C;
const int _underscore = 0x5F;
const int _lowerA = 0x61;
const int _lowerR = 0x72;
const int _lowerZ = 0x7A;
const int _openBrace = 0x7B;
const int _closeBrace = 0x7D;
