/// declared-arguments — an argument a step accepts is an argument something reads.
///
/// **The failure this exists for is the quiet half of a pair.** A row naming an argument the step
/// does NOT declare is refused by name before anything runs, which is loud and easy. A row naming
/// one the step declares and never reads is ACCEPTED: the argument check passes, because the name is
/// declared, and nothing ever looks it up. The row runs, does nothing about it, and reports success.
///
/// It happened twice in one day. One argument was declared as `skippable_answers` and read as
/// `skippable_answer`, so the capability it advertised was unreachable by any row. Five more were
/// declared, carried through every use inside the class, and never taken out of the arguments at
/// all — so five steps ignored what their rows told them, on every machine, and two of them proved
/// it by failing on a real one after the rest of the run had already happened.
///
/// **A declaration written INLINE and one written as a NAMED CONSTANT are two different promises,
/// and the tree already writes them differently.** An inline one sits in a step's own list and
/// belongs to that step, so that step's file has to read it. A named one exists to be put in SEVERAL
/// steps' lists — a client invocation, a status command — and is read by whoever uses it, which is
/// never the file that declares it.
///
/// So an inline declaration is judged against its own file, and a named one against the whole scan.
/// Judging both the same way was tried and was wrong in both directions: per file it reported three
/// shared declarations that two neighbours read correctly, and tree-wide it would let a misspelled
/// argument pass because some other step happens to use the same word.
///
/// **What this cannot do, said plainly.** It is a text scan. A file that builds its argument name out
/// of pieces, or reads it through a constant declared somewhere else, passes without being read —
/// and a file that merely mentions the name in a comment passes too. It is a good sample rather than
/// a proof, and it is worth having because both of the failures above are exactly the shape it
/// catches.
library;

import 'finding.dart';
import 'source_tree.dart';
import 'word_purity.dart';

/// One argument a file declares, and where it declares it.
final class DeclaredArgument {
  /// Records that [path] declares [name] at [line].
  const DeclaredArgument({
    required this.path,
    required this.line,
    required this.name,
    this.shared = false,
  });

  /// The repository-relative file the declaration sits in.
  final String path;

  /// The line the declaration's name sits on, counted from one.
  final int line;

  /// The name a program row writes.
  final String name;

  /// Whether the declaration is a NAMED constant, which exists to be used by other files.
  ///
  /// An inline declaration sits in one step's own list and is that step's; a named one is put in
  /// several lists and is read by whoever uses it.
  final bool shared;
}

/// Every argument declared in [scanned] that nothing in its own file reads.
final class DeclaredArguments {
  /// Judges the files of [tree] under [scanned].
  const DeclaredArguments({required this.tree, required this.scanned});

  /// The tree the files are read from.
  final SourceTree tree;

  /// The directories read, named one at a time so that widening the scan is a decision.
  final List<String> scanned;

  /// The files judged, which is what the count in a report is stated against.
  List<String> get files => scannedFilesOf(tree, scanned);

  /// Every argument any judged file declares.
  List<DeclaredArgument> get declared => <DeclaredArgument>[
    for (final String path in files)
      for (final DeclaredArgument each in argumentsDeclaredIn(tree.textOf(path) ?? '', path)) each,
  ];

  /// Every declaration whose name appears nowhere else in the file that declares it.
  List<Finding> get findings {
    // Every judged file with its declarations taken out, which is where a SHARED argument is read:
    // a file declaring one for several steps to use never reads it itself, and is not meant to.
    final String everywhere = <String>[
      for (final String path in files) _withoutSpecs(tree.textOf(path) ?? ''),
    ].join(' ');
    return <Finding>[
      for (final String path in files)
        ...findingsIn(tree.textOf(path) ?? '', path, alsoRead: everywhere),
    ];
  }

  /// The findings of one file's [text], with [alsoRead] standing for the rest of the scan.
  ///
  /// [alsoRead] is where a NAMED declaration is looked for, since it exists to be used elsewhere. An
  /// inline one is looked for in [text] alone.
  static List<Finding> findingsIn(String text, String path, {String alsoRead = ''}) {
    final String hereElsewhere = _withoutSpecs(text);
    return <Finding>[
      for (final DeclaredArgument each in argumentsDeclaredIn(text, path))
        if (!(each.shared ? '$hereElsewhere$alsoRead' : hereElsewhere).contains("'${each.name}'"))
          Finding(
            path,
            each.shared
                ? 'declares the shared argument "${each.name}" and nothing in the whole scan reads '
                      'it — a row writing it is accepted and then ignored, which reports success '
                      'for work that did not happen'
                : 'declares the argument "${each.name}" and nothing in this file reads it — a row '
                      'writing it is accepted and then ignored, which reports success for work that '
                      'did not happen',
            line: each.line,
          ),
    ];
  }
}

/// The arguments declared in [text], with the line each name sits on.
List<DeclaredArgument> argumentsDeclaredIn(String text, String path) {
  final List<String> lines = text.split('\n');
  final List<DeclaredArgument> found = <DeclaredArgument>[];
  bool inSpec = false;
  bool shared = false;
  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];
    if (line.contains('ArgumentSpec(')) {
      inSpec = true;
      // `= ArgumentSpec(` is a declaration with a name of its own, which exists to be used
      // elsewhere. Anything else is an entry in a list, which belongs to the step holding it.
      shared = RegExp(r'=\s*(const\s+)?ArgumentSpec\(').hasMatch(line);
      // A one-line declaration carries its name on the same line as the opening.
      if (_nameOn(line) case final String name) {
        found.add(DeclaredArgument(path: path, line: i + 1, name: name, shared: shared));
        inSpec = !line.contains(')');
      }
      continue;
    }
    if (!inSpec) {
      continue;
    }
    if (_nameOn(line) case final String name) {
      found.add(DeclaredArgument(path: path, line: i + 1, name: name, shared: shared));
      inSpec = false;
      continue;
    }
    // A spec ends at its closing bracket. Anything after it is ordinary code again.
    if (line.trimLeft().startsWith(')')) {
      inSpec = false;
    }
  }
  return found;
}

/// [text] with every `ArgumentSpec(...)` taken out, so what is left is where a read would be.
///
/// Removed by counting brackets rather than by a pattern, because a spec's `describes` runs over
/// several lines and carries brackets of its own.
String _withoutSpecs(String text) {
  final StringBuffer kept = StringBuffer();
  int i = 0;
  while (true) {
    final int start = text.indexOf('ArgumentSpec(', i);
    if (start < 0) {
      kept.write(text.substring(i));
      return kept.toString();
    }
    kept.write(text.substring(i, start));
    int depth = 0;
    int j = start + 'ArgumentSpec'.length;
    for (; j < text.length; j++) {
      if (text[j] == '(') {
        depth++;
      } else if (text[j] == ')') {
        depth--;
        if (depth == 0) {
          j++;
          break;
        }
      }
    }
    i = j;
  }
}

/// The name a `name: '…'` line carries, or null where the line is not one.
String? _nameOn(String line) {
  final RegExpMatch? match = RegExp(r"\bname:\s*'([a-z][a-z0-9_]*)'").firstMatch(line);
  return match?.group(1);
}
