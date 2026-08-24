/// What a file's `ArgumentSpec` declarations say, read out of its text.
///
/// **Two scans ask the same questions of one file and they have to answer them the same way.**
/// declared-arguments asks what a file DECLARES so it can look for the read; carried-arguments asks
/// the same thing so it can decide whether a read is covered. A file that declared an argument for
/// one of them and not for the other would be reported by one and passed by the other, and the pair
/// that claims to close the question in both directions would have a hole between them.
///
/// **A step declares an argument in TWO ways, and only one of them is written out.** It either puts
/// an `ArgumentSpec(...)` in its own list, name and all, or it puts the IDENTIFIER of a spec somebody
/// else declared — the framework's own elevation spec, or one a package declares once for several of
/// its steps. The second carries no `name:` anywhere in the file, and the resolver treats the two
/// exactly alike: a value is delivered under every name the step's list declares, however that entry
/// was written.
///
/// **An identifier counts only where it stands BARE.** Qualified it names that class's own constant,
/// which declares a different name and is read by that class rather than by the step listing it; and
/// followed by `=` it is the declaration itself, so the one file that declares a spec has not thereby
/// put it in any list.
library;

import 'source_tree.dart';

/// The shared specs the framework itself hands every plugin: identifier against declared name.
///
/// The framework package is never inside a scanned tree, so no scan can resolve these identifiers
/// by reading a declaration — they are written out here instead. There is exactly one, and it is
/// the elevation spec every step that reaches a root-owned path puts in its own list.
const Map<String, String> frameworkSharedSpecs = <String, String>{'elevationArgument': 'elevated'};

/// The shared specs of a whole scan: the framework's own, over every one [texts] declares.
///
/// A shared spec is declared in one file and put in other files' lists, so resolving one takes the
/// whole scan — which is why this is built over every file and handed to each file's judgement.
Map<String, String> sharedSpecsOf(Iterable<String> texts) => <String, String>{
  ...frameworkSharedSpecs,
  for (final String text in texts) ...sharedSpecsDeclaredIn(text),
};

/// The shared spec constants [text] declares: identifier against the name each declares.
///
/// A shared spec is a top-level `const ArgumentSpec <identifier> = ArgumentSpec(...)`. A `static`
/// one is a class's own and is excluded on purpose: it is referenced qualified, so its bare
/// identifier standing in some other file must not resolve to it — that is exactly the substring
/// mistake these scans exist to refuse.
Map<String, String> sharedSpecsDeclaredIn(String text) {
  final Map<String, String> declared = <String, String>{};
  for (final RegExpMatch match in _sharedSpecDeclaration.allMatches(text)) {
    if (match.group(1) != null) {
      continue;
    }
    final String? name = nameIn(balancedFrom(text, match.end - 1));
    if (name != null) {
      declared[match.group(2)!] = name;
    }
  }
  return declared;
}

/// One shared spec a file LISTS, and where.
final class ListedSpec {
  /// Records that a file listed [identifier], declaring [name], at [line].
  const ListedSpec({required this.identifier, required this.name, required this.line});

  /// The identifier the file wrote.
  final String identifier;

  /// The name that identifier declares, which is what a program row writes.
  final String name;

  /// The line the identifier stands on, counted from one.
  final int line;
}

/// The specs of [sharedSpecs] that [text] LISTS, by the name each declares.
///
/// This is a step's OWN declaration written as an identifier, and it is why a step whose list
/// carries nothing but `elevationArgument` still receives whatever a row — or a program-wide default
/// — writes under `elevated`.
Map<String, ListedSpec> sharedSpecsListedIn(
  String text, {
  Map<String, String> sharedSpecs = frameworkSharedSpecs,
}) {
  final Map<String, ListedSpec> listed = <String, ListedSpec>{};
  for (final MapEntry<String, String> spec in sharedSpecs.entries) {
    if (_bare(spec.key).firstMatch(text) case final RegExpMatch match) {
      listed.putIfAbsent(
        spec.value,
        () => ListedSpec(identifier: spec.key, name: spec.value, line: lineAt(text, match.start)),
      );
    }
  }
  return listed;
}

/// Every argument name any `ArgumentSpec(...)` region of [text] writes out.
///
/// Read by counting brackets rather than by a pattern per line, because a spec's `describes` runs
/// over several lines and carries brackets of its own.
Set<String> namesDeclaredIn(String text) {
  final Set<String> declared = <String>{};
  int i = 0;
  while (true) {
    final int start = text.indexOf(_specOpening, i);
    if (start < 0) {
      return declared;
    }
    final String region = balancedFrom(text, start + _specOpening.length - 1);
    if (nameIn(region) case final String name) {
      declared.add(name);
    }
    i = start + region.length;
  }
}

/// [text] with every `ArgumentSpec(...)` taken out, so what is left is where a read would be.
///
/// The description of an argument usually repeats its own name, so a scan searching the whole file
/// would call every declaration read.
String withoutSpecs(String text) {
  final StringBuffer kept = StringBuffer();
  int i = 0;
  while (true) {
    final int start = text.indexOf(_specOpening, i);
    if (start < 0) {
      kept.write(text.substring(i));
      return kept.toString();
    }
    kept.write(text.substring(i, start));
    i =
        start +
        balancedFrom(text, start + _specOpening.length - 1).length +
        _specOpening.length -
        1;
  }
}

/// The text from the opening bracket at [openBracket] to the bracket closing it, inclusive.
String balancedFrom(String text, int openBracket) {
  int depth = 0;
  for (int i = openBracket; i < text.length; i++) {
    if (text[i] == '(') {
      depth++;
    } else if (text[i] == ')') {
      depth--;
      if (depth == 0) {
        return text.substring(openBracket, i + 1);
      }
    }
  }
  return text.substring(openBracket);
}

/// The name the first `name: '…'` of [region] carries, or null where there is none.
String? nameIn(String region) =>
    RegExp(r"\bname:\s*'([a-z][a-z0-9_]*)'").firstMatch(region)?.group(1);

/// What every spec written out begins with, opening bracket included.
const String _specOpening = 'ArgumentSpec(';

/// A spec constant's declaration line, with its `static` — where it has one — captured.
final RegExp _sharedSpecDeclaration = RegExp(
  r'^\s*(static\s+)?const ArgumentSpec\s+([a-zA-Z_$][\w$]*)\s*=\s*ArgumentSpec\(',
  multiLine: true,
);

/// [identifier] standing unqualified and in use, rather than qualified or being declared.
RegExp _bare(String identifier) =>
    RegExp('(?<![.\\w\$])${RegExp.escape(identifier)}(?![\\w\$])(?!\\s*=)');
