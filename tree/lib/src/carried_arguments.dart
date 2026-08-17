/// carried-arguments — what a row grants a step is carried all the way to the act.
///
/// **The two shapes this exists for cost one real machine run each to find, and nothing reported
/// either.** They are the two hops of the same carriage: an argument's value travels from the
/// program row into the step, and from the step into every call the step makes. This scan judges
/// both hops, because a value dropped on either one fails the same way — silently, and only on a
/// machine.
///
/// **The first hop: a step READS an argument it does not DECLARE.** The resolver fills a
/// program-wide default only under a name the step's argument list declares, so in such a step
/// `arguments.has('elevated')` answers no, the value never arrives, and the step runs as the
/// account the run started as whatever the row says. Nothing refuses anything: the read is spelled
/// correctly, the row is valid, and the run reports success. Ten steps had it on one day — eight of
/// them because their list carried `Client.elevationArgument`, a DIFFERENT argument whose constant
/// merely ends in the same identifier, and a substring comparison took it for a declaration. So an
/// identifier here counts only where it stands BARE: qualified, it names that class's own constant
/// and never the shared one, and at its own declaration it declares rather than uses.
///
/// **The second hop: a file carries `final bool elevated;` and one files-port call does not pass it
/// on.** The elevation the row granted reached the step and is dropped at the last moment: that one
/// call acts as the operator, and a path root owns turns into a failure three steps from the
/// reason. Four calls had it on the same day. Such a call runs over several lines and carries
/// brackets inside its own arguments, so it is read by counting brackets rather than by a pattern
/// per line — and the elevation is looked for only among the call's OWN arguments, because an inner
/// call that passes it does not cover the outer one that does not.
///
/// This is the mirror of declared-arguments, which catches the opposite half of the first hop:
/// declared and never read. Between the two, a step's declarations and its reads have to agree in
/// both directions.
///
/// **What this cannot do, said plainly.** It is a text scan. The first hop sees only reads written
/// literally as `arguments.<method>('name')`, takes any bare mention of a shared spec's identifier
/// as a declaration wherever in the file it stands, and resolves an identifier declared outside the
/// scanned tree only where [frameworkSharedSpecs] names it. The second hop sees only calls written
/// literally on `context.files`, judges only files that write the elevation field exactly as
/// [elevationField], and a string among a call's own arguments that says `elevated` counts as
/// passing it. A value handed onward through a helper of the step's own is not followed. It is a
/// good sample rather than a proof, and both of the failures above are exactly the shape it
/// catches.
library;

import 'finding.dart';
import 'source_tree.dart';
import 'word_purity.dart';

/// The field a step carries a granted elevation in, written the way every step writes it.
const String elevationField = 'final bool elevated;';

/// The shared specs the framework itself hands every plugin: identifier against declared name.
///
/// The framework package is never inside a scanned tree, so no scan can resolve these identifiers
/// by reading a declaration — they are written out here instead. There is exactly one, and it is
/// the elevation spec every step that reaches a root-owned path puts in its own list.
const Map<String, String> frameworkSharedSpecs = <String, String>{'elevationArgument': 'elevated'};

/// One argument a file reads out of what the program gave it, and where.
final class ArgumentRead {
  /// Records that [path] reads [name] at [line].
  const ArgumentRead({required this.path, required this.line, required this.name});

  /// The repository-relative file the read sits in.
  final String path;

  /// The line the read sits on, counted from one.
  final int line;

  /// The name the read looks up.
  final String name;
}

/// One call a file makes on the files port, and whether it passes the elevation on.
final class FilesPortCall {
  /// Records the [method] call of [path] at [line].
  const FilesPortCall({
    required this.path,
    required this.line,
    required this.method,
    required this.carriesElevation,
  });

  /// The repository-relative file the call sits in.
  final String path;

  /// The line the call starts on, counted from one.
  final int line;

  /// The port method the call names.
  final String method;

  /// Whether the call's own arguments carry the elevation.
  final bool carriesElevation;
}

/// Every argument read that no declaration covers, and every files-port call that drops a carried
/// elevation, in the files of [scanned].
final class CarriedArguments {
  /// Judges the files of [tree] under [scanned].
  const CarriedArguments({required this.tree, required this.scanned});

  /// The tree the files are read from.
  final SourceTree tree;

  /// The directories read, named one at a time so that widening the scan is a decision.
  final List<String> scanned;

  /// The files judged, which is what the count in a report is stated against.
  List<String> get files => scannedFilesOf(tree, scanned);

  /// The shared spec constants of the whole scan, identifier against declared name, over the
  /// framework's own.
  ///
  /// A shared spec is declared in one file and put in other files' lists, so resolving one takes
  /// the whole scan — which is why the map is built here and handed to every file's judgement.
  Map<String, String> get sharedSpecs => <String, String>{
    ...frameworkSharedSpecs,
    for (final String path in files) ...sharedSpecsDeclaredIn(tree.textOf(path) ?? ''),
  };

  /// Every argument read any judged file makes.
  List<ArgumentRead> get reads => <ArgumentRead>[
    for (final String path in files)
      for (final ArgumentRead each in argumentReadsIn(tree.textOf(path) ?? '', path)) each,
  ];

  /// The judged files that carry the elevation field.
  List<String> get elevationCarriers => <String>[
    for (final String path in files)
      if ((tree.textOf(path) ?? '').contains(elevationField)) path,
  ];

  /// Every files-port call of a file that carries the elevation field.
  List<FilesPortCall> get calls => <FilesPortCall>[
    for (final String path in files)
      for (final FilesPortCall each in filesPortCallsIn(tree.textOf(path) ?? '', path)) each,
  ];

  /// Every dropped value of both hops, across the judged files.
  List<Finding> get findings {
    final Map<String, String> shared = sharedSpecs;
    return <Finding>[
      for (final String path in files)
        ...findingsIn(tree.textOf(path) ?? '', path, sharedSpecs: shared),
    ];
  }

  /// The findings of one file's [text], with [sharedSpecs] standing for the rest of the scan.
  ///
  /// [sharedSpecs] is where a read that no declaration in [text] covers is resolved: an identifier
  /// mapped to the read's name counts as a declaration where it stands bare in [text]. The default
  /// is the framework's own map, which is in scope for every file of every tree.
  static List<Finding> findingsIn(
    String text,
    String path, {
    Map<String, String> sharedSpecs = frameworkSharedSpecs,
  }) {
    final Set<String> declaredHere = _namesDeclaredIn(text);
    // One finding per name: `has` and the read beside it look the same argument up twice.
    final Set<String> reported = <String>{};
    return <Finding>[
      for (final ArgumentRead read in argumentReadsIn(text, path))
        if (!declaredHere.contains(read.name) &&
            !_aBareIdentifierDeclares(text, read.name, sharedSpecs) &&
            reported.add(read.name))
          Finding(
            path,
            'reads the argument "${read.name}" and declares it nowhere — a value is delivered '
            'only under a declared name, so the read answers as if no row had written it and '
            'the step quietly does without',
            line: read.line,
          ),
      for (final FilesPortCall call in filesPortCallsIn(text, path))
        if (!call.carriesElevation)
          Finding(
            path,
            'carries the elevation a row may grant and does not pass it to this '
            '${call.method} call — the call acts as the account the run started as, '
            'whatever the row said',
            line: call.line,
          ),
    ];
  }

  /// Whether an identifier of [sharedSpecs] declaring [name] stands bare in [text].
  ///
  /// Bare means unqualified and in use: preceded by a dot it names a class's own constant, and
  /// followed by `=` it is being declared rather than put in a list — a file declaring a static
  /// spec under a shared spec's identifier has not thereby put the shared one in any list.
  static bool _aBareIdentifierDeclares(String text, String name, Map<String, String> sharedSpecs) {
    for (final MapEntry<String, String> spec in sharedSpecs.entries) {
      if (spec.value != name) {
        continue;
      }
      final RegExp bare = RegExp('(?<![.\\w\$])${RegExp.escape(spec.key)}(?![\\w\$])(?!\\s*=)');
      if (bare.hasMatch(text)) {
        return true;
      }
    }
    return false;
  }
}

/// The argument reads of [text], with the line each sits on.
///
/// A read is `arguments.<method>('name')` with the name written out — the six methods the
/// framework's argument surface has. A name built out of pieces is not seen, and is one of the
/// stated limits.
List<ArgumentRead> argumentReadsIn(String text, String path) => <ArgumentRead>[
  for (final RegExpMatch match in _argumentRead.allMatches(text))
    ArgumentRead(path: path, line: _lineAt(text, match.start), name: match.group(1)!),
];

/// The shared spec constants [text] declares: identifier against the name each declares.
///
/// A shared spec is a top-level `const ArgumentSpec <identifier> = ArgumentSpec(...)`. A `static`
/// one is a class's own and is excluded on purpose: it is referenced qualified, so its bare
/// identifier standing in some other file must not resolve to it — that is exactly the substring
/// mistake this scan exists to refuse.
Map<String, String> sharedSpecsDeclaredIn(String text) {
  final Map<String, String> declared = <String, String>{};
  for (final RegExpMatch match in _sharedSpecDeclaration.allMatches(text)) {
    if (match.group(1) != null) {
      continue;
    }
    final String? name = _nameIn(_balancedFrom(text, match.end - 1));
    if (name != null) {
      declared[match.group(2)!] = name;
    }
  }
  return declared;
}

/// The files-port calls of [text], or none where [text] does not carry the elevation field.
///
/// A file without the field owes elevation to no call, so its calls are not judged and not
/// counted. Each call is read to its closing bracket by counting brackets, and the elevation is
/// looked for only among the call's own arguments — never inside a nested call's.
List<FilesPortCall> filesPortCallsIn(String text, String path) {
  if (!text.contains(elevationField)) {
    return const <FilesPortCall>[];
  }
  return <FilesPortCall>[
    for (final RegExpMatch match in _filesPortCall.allMatches(text))
      FilesPortCall(
        path: path,
        line: _lineAt(text, match.start),
        method: match.group(1)!,
        carriesElevation: _elevatedWord.hasMatch(_ownArgumentsOf(text, match.end - 1)),
      ),
  ];
}

/// A read on the framework's argument surface, longest method name first so none shadows another.
final RegExp _argumentRead = RegExp(
  r"\barguments\.(?:optionalText|textList|integer|text|flag|has)\(\s*'([a-z][a-z0-9_]*)'",
);

/// A spec constant's declaration line, with its `static` — where it has one — captured.
final RegExp _sharedSpecDeclaration = RegExp(
  r'^\s*(static\s+)?const ArgumentSpec\s+([a-zA-Z_$][\w$]*)\s*=\s*ArgumentSpec\(',
  multiLine: true,
);

/// A call on the files port, with the method it names captured.
final RegExp _filesPortCall = RegExp(
  r'\bcontext\.files\.(exists|read|write|delete|createDirectory|list)\(',
);

/// The elevation standing as its own word, so a longer name that merely contains it is none.
final RegExp _elevatedWord = RegExp(r'(?<![\w$])elevated(?![\w$])');

/// Every argument name any `ArgumentSpec(...)` region of [text] declares.
///
/// Read by counting brackets rather than by a pattern per line, because a spec's `describes` runs
/// over several lines and carries brackets of its own.
Set<String> _namesDeclaredIn(String text) {
  final Set<String> declared = <String>{};
  int i = 0;
  while (true) {
    final int start = text.indexOf('ArgumentSpec(', i);
    if (start < 0) {
      return declared;
    }
    final String region = _balancedFrom(text, start + 'ArgumentSpec'.length);
    if (_nameIn(region) case final String name) {
      declared.add(name);
    }
    i = start + region.length;
  }
}

/// The text from the opening bracket at [openBracket] to the bracket closing it, inclusive.
String _balancedFrom(String text, int openBracket) {
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

/// What stands directly between a call's brackets, with every nested bracket's inside left out.
///
/// This is where a passed elevation lives: `elevated: elevated` among the call's own arguments.
/// The same word inside a nested call belongs to that call, and keeping it out is what makes an
/// outer call that drops the elevation reportable beside an inner one that does not.
String _ownArgumentsOf(String text, int openBracket) {
  final StringBuffer own = StringBuffer();
  int depth = 1;
  for (int i = openBracket + 1; i < text.length; i++) {
    final String char = text[i];
    if (char == '(') {
      depth++;
      continue;
    }
    if (char == ')') {
      depth--;
      if (depth == 0) {
        break;
      }
      continue;
    }
    if (depth == 1) {
      own.write(char);
    }
  }
  return own.toString();
}

/// The name the first `name: '…'` of [region] carries, or null where there is none.
String? _nameIn(String region) =>
    RegExp(r"\bname:\s*'([a-z][a-z0-9_]*)'").firstMatch(region)?.group(1);

/// The line, counted from one, that [offset] of [text] sits on.
int _lineAt(String text, int offset) {
  int line = 1;
  for (int i = 0; i < offset; i++) {
    if (text.codeUnitAt(i) == 0x0A) {
      line++;
    }
  }
  return line;
}
