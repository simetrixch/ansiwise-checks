/// declared-arguments — an argument a step accepts is an argument something reads.
///
/// **The failure this exists for is the quiet half of a pair.** A row naming an argument the step
/// does NOT declare is refused by name before anything runs, which is loud and easy. A row naming
/// one the step declares and never reads is ACCEPTED: the argument check passes, because the name is
/// declared, and nothing ever looks it up. The row runs, does nothing about it, and reports success.
///
/// It takes two shapes. An argument declared as `skippable_answers` and read as `skippable_answer`
/// advertises a capability no row can reach. An argument declared, carried through every use inside
/// the class, and never taken out of the arguments at all leaves a step ignoring what its row tells
/// it, on every machine, until it fails on a real one after the rest of the run has already
/// happened.
///
/// **A declaration is written in three ways, and the third is the one that carries no name at all.**
/// An INLINE one sits in a step's own list and belongs to that step, so that step's file has to read
/// it. A NAMED CONSTANT exists to be put in SEVERAL steps' lists — a client invocation, a status
/// command — and is read by whoever uses it, which is never the file that declares it. A LISTED one
/// is a step putting somebody else's identifier in its own list: the framework's `elevationArgument`,
/// or a constant a package declares once. It is that step's own declaration exactly as an inline one
/// is, and the resolver delivers a value under it exactly the same way — but the file holds no
/// `name:` anywhere, so a scan reading only what is written out sees a step that declares nothing.
///
/// That is what lets a step declare the elevation, carry `final bool elevated;`, never read the
/// argument, and pass every check: the field stays false on every machine while a program-wide
/// default says `elevated: true`, and the command it grants root for is refused by a snap. The
/// second run of the same program passes, because the account has by then started a session
/// carrying the group it was put into.
///
/// So an inline and a listed declaration are judged against their own file, and a named one against
/// the whole scan. Judging inline and named the same way is wrong in both directions: per file it
/// reports three shared declarations that two neighbours read correctly, and tree-wide it lets a
/// misspelled argument pass because some other step happens to use the same word.
///
/// **What this cannot do, said plainly.** It is a text scan. A file that builds its argument name out
/// of pieces, or reads it through a constant declared somewhere else, passes without being read —
/// and a file that merely mentions the name in a comment passes too. A listed declaration is seen
/// only where its identifier stands bare, so a qualified one — a class's own spec, which that class
/// reads — is left to the class that owns it. It is a good sample rather than a proof, and it is
/// worth having because all three of the failures above are exactly the shape it catches.
library;

import 'argument_specs.dart';
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
    this.identifier,
  });

  /// The repository-relative file the declaration sits in.
  final String path;

  /// The line the declaration sits on, counted from one.
  final int line;

  /// The name a program row writes.
  final String name;

  /// Whether the declaration is a NAMED constant, which exists to be used by other files.
  ///
  /// An inline declaration sits in one step's own list and is that step's; a named one is put in
  /// several lists and is read by whoever uses it.
  final bool shared;

  /// The identifier this file LISTED to declare [name], or null where the name is written out here.
  ///
  /// A listed declaration carries no `name:` in this file, so a finding about one has to name the
  /// identifier the reader will find on that line.
  final String? identifier;
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

  /// The shared spec constants of the whole scan, identifier against declared name, over the
  /// framework's own.
  ///
  /// A shared spec is declared in one file and listed in others, so resolving one takes the whole
  /// scan — which is why the map is built here and handed to every file's judgement.
  Map<String, String> get sharedSpecs =>
      sharedSpecsOf(<String>[for (final String path in files) tree.textOf(path) ?? '']);

  /// Every argument any judged file declares, however it declares it.
  List<DeclaredArgument> get declared {
    final Map<String, String> shared = sharedSpecs;
    return <DeclaredArgument>[
      for (final String path in files)
        for (final DeclaredArgument each in argumentsDeclaredIn(
          tree.textOf(path) ?? '',
          path,
          sharedSpecs: shared,
        ))
          each,
    ];
  }

  /// Every declaration a file makes by LISTING an identifier somebody else declared.
  ///
  /// Stated beside the count of everything declared rather than folded into it, because a half that
  /// judges nothing reads exactly like a half that found nothing.
  List<DeclaredArgument> get listed => <DeclaredArgument>[
    for (final DeclaredArgument each in declared)
      if (each.identifier != null) each,
  ];

  /// Every declaration whose name appears nowhere else in the file that declares it.
  List<Finding> get findings {
    // Every judged file with its declarations taken out, which is where a SHARED argument is read:
    // a file declaring one for several steps to use never reads it itself, and is not meant to.
    final String everywhere = <String>[
      for (final String path in files) withoutSpecs(tree.textOf(path) ?? ''),
    ].join(' ');
    final Map<String, String> shared = sharedSpecs;
    return <Finding>[
      for (final String path in files)
        ...findingsIn(tree.textOf(path) ?? '', path, alsoRead: everywhere, sharedSpecs: shared),
    ];
  }

  /// The findings of one file's [text], with [alsoRead] standing for the rest of the scan.
  ///
  /// [alsoRead] is where a NAMED declaration is looked for, since it exists to be used elsewhere. An
  /// inline one and a listed one are looked for in [text] alone.
  ///
  /// [sharedSpecs] is what an identifier listed in [text] is resolved against. The default is the
  /// framework's own map, which is in scope for every file of every tree.
  static List<Finding> findingsIn(
    String text,
    String path, {
    String alsoRead = '',
    Map<String, String> sharedSpecs = frameworkSharedSpecs,
  }) {
    final String hereElsewhere = withoutSpecs(text);
    return <Finding>[
      for (final DeclaredArgument each in argumentsDeclaredIn(text, path, sharedSpecs: sharedSpecs))
        if (!(each.shared ? '$hereElsewhere$alsoRead' : hereElsewhere).contains("'${each.name}'"))
          Finding(path, _whatIsWrong(each), line: each.line),
    ];
  }
}

/// What a declaration nothing reads costs, in the words a reader decides from.
String _whatIsWrong(DeclaredArgument declaration) {
  const String ignored =
      'is accepted and then ignored, which reports success for work that did not happen';
  if (declaration.identifier case final String identifier) {
    return 'lists "$identifier", which declares the argument "${declaration.name}", and nothing in '
        'this file reads it — the resolver delivers a value under every name a step declares, so a '
        'row or a program-wide default writing it $ignored';
  }
  return declaration.shared
      ? 'declares the shared argument "${declaration.name}" and nothing in the whole scan reads it '
            '— a row writing it $ignored'
      : 'declares the argument "${declaration.name}" and nothing in this file reads it — a row '
            'writing it $ignored';
}

/// The arguments declared in [text], with the line each sits on.
///
/// [sharedSpecs] is what an identifier listed here is resolved against: listing one declares the
/// argument it names, for this file, exactly as writing the name out would.
List<DeclaredArgument> argumentsDeclaredIn(
  String text,
  String path, {
  Map<String, String> sharedSpecs = frameworkSharedSpecs,
}) {
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
  for (final ListedSpec each in sharedSpecsListedIn(text, sharedSpecs: sharedSpecs).values) {
    found.add(
      DeclaredArgument(path: path, line: each.line, name: each.name, identifier: each.identifier),
    );
  }
  return found;
}

/// The name a `name: '…'` line carries, or null where the line is not one.
String? _nameOn(String line) {
  final RegExpMatch? match = RegExp(r"\bname:\s*'([a-z][a-z0-9_]*)'").firstMatch(line);
  return match?.group(1);
}
