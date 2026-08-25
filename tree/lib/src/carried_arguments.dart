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
/// merely ends in the same identifier, and a substring comparison took it for a declaration.
///
/// **The second hop: a file carries the elevation and one call does not pass it on.** The elevation
/// the row granted reached the step and is dropped at the last moment: that one call acts as the
/// operator, and a path root owns turns into a failure three steps from the reason.
///
/// **A FILE CARRIES IT IN A FIELD OR IN A PARAMETER, and for a while only the field was looked at.**
/// A step keeps the row's answer in `final bool elevated;` and hands it to a helper of its own as a
/// parameter, and such a helper's file writes the field nowhere — so a gate on the field text alone
/// judged no call in it at all. Six calls stood behind that gate on 2026-08-25, one of them a shell
/// command, and every one of them was correct, which is why the hole was worth stating before it
/// cost a run rather than after.
///
/// So a call is judged wherever an elevation STANDS OVER it: anywhere in a file that writes the
/// field exactly as [elevationField], and inside the BODY of a function whose parameter list
/// declares `bool elevated`. Scoped to that body rather than to the whole file, because a helper
/// taking the elevation says nothing about the function written beside it — a gate on the file
/// would report a call that has no elevation to pass, and a scan reporting calls nobody can fix is
/// the noise that teaches people to stop reading it. Measured over the twelve packages this audit
/// runs in, widening the gate this way brought 3 more files and 6 more calls under the scan and
/// reported none of them.
///
/// **BOTH PORTS, because a step reaches the machine through both and the drop looks the same on
/// either.** Through the files port the elevation is a named argument of the call itself. Through
/// the shell it is a field of the `Command`, so what is judged is where the command is COMPOSED —
/// `context.shell.run` only carries what the command already says, and a scan reading `run`'s own
/// arguments would report every step in the tree and see nothing. Four files-port calls dropped it
/// on one day; the shell half was measured on the day `export_kubeconfig` asked a cluster for its
/// credentials as the operator, on a machine whose account had been put into the group granting
/// access one step earlier — supplementary groups are read once, when a session starts, so the
/// second run of the same program passed and the first never could.
///
/// Such a call runs over several lines and carries brackets inside its own arguments, so it is read
/// by counting brackets rather than by a pattern per line — and the elevation is looked for only
/// among the call's OWN arguments, because an inner call that passes it does not cover the outer one
/// that does not.
///
/// This is the mirror of declared-arguments, which catches the opposite half of the first hop:
/// declared and never read. Between the two, a step's declarations and its reads have to agree in
/// both directions.
///
/// **What this cannot do, said plainly.** It is a text scan. The first hop sees only reads written
/// literally as `arguments.<method>('name')`, takes any bare mention of a shared spec's identifier
/// as a declaration wherever in the file it stands, and resolves an identifier declared outside the
/// scanned tree only where [frameworkSharedSpecs] names it. The second hop sees only calls written
/// literally on `context.files` and commands written literally as `Command(...)`, sees an elevation
/// standing over a call only as the field written exactly as [elevationField] or as a parameter
/// written exactly as `bool elevated`, and a string among a call's own arguments that says
/// `elevated` counts as passing it. A command handed to `run` as a variable is not followed, and
/// neither is the value itself: a helper the step hands the elevation to is judged on its own
/// parameter, never on the call that fills it, so a caller passing the wrong answer is a thing this
/// scan cannot see. It is a good sample rather than a proof, and both of the failures above are
/// exactly the shape it catches.
library;

import 'argument_specs.dart';
import 'finding.dart';
import 'source_tree.dart';
import 'word_purity.dart';

/// The field a step carries a granted elevation in, written the way every step writes it.
const String elevationField = 'final bool elevated;';

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

/// Which port a call reaches the machine through.
enum Port {
  /// A call written on `context.files`, which takes the elevation as a named argument.
  files,

  /// A `Command`, which carries the elevation as a field of its own and is judged where it is
  /// composed rather than where it is run.
  shell,
}

/// One call a file makes that reaches the machine, and whether it passes the elevation on.
final class PortCall {
  /// Records the [method] call of [path] at [line], reaching the machine through [port].
  const PortCall({
    required this.path,
    required this.line,
    required this.port,
    required this.method,
    required this.carriesElevation,
  });

  /// The repository-relative file the call sits in.
  final String path;

  /// The line the call starts on, counted from one.
  final int line;

  /// Which port it reaches the machine through.
  final Port port;

  /// What the call names: the port method, or the command constructor.
  final String method;

  /// Whether the call's own arguments carry the elevation.
  final bool carriesElevation;
}

/// Every argument read that no declaration covers, and every call that drops a carried elevation,
/// in the files of [scanned].
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
  Map<String, String> get sharedSpecs =>
      sharedSpecsOf(<String>[for (final String path in files) tree.textOf(path) ?? '']);

  /// Every argument read any judged file makes.
  List<ArgumentRead> get reads => <ArgumentRead>[
    for (final String path in files)
      for (final ArgumentRead each in argumentReadsIn(tree.textOf(path) ?? '', path)) each,
  ];

  /// The judged files that carry the elevation, in a field or in a parameter.
  List<String> get elevationCarriers => <String>[
    for (final String path in files)
      if (_elevationScopesIn(tree.textOf(path) ?? '').isNotEmpty) path,
  ];

  /// Every call an elevation stands over, through either port.
  List<PortCall> get calls => <PortCall>[
    for (final String path in files)
      for (final PortCall each in portCallsIn(tree.textOf(path) ?? '', path)) each,
  ];

  /// Every judged call written on the files port.
  List<PortCall> get filesPortCalls => <PortCall>[
    for (final PortCall each in calls)
      if (each.port == Port.files) each,
  ];

  /// Every judged command, counted where it is composed.
  ///
  /// Stated beside [filesPortCalls] rather than added to it, because a half that judges nothing
  /// reads exactly like a half that found nothing — and that is what let a step compose an
  /// unelevated command under a scan reporting a clean tree.
  List<PortCall> get commandCalls => <PortCall>[
    for (final PortCall each in calls)
      if (each.port == Port.shell) each,
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
    final Set<String> writtenOut = namesDeclaredIn(text);
    final Map<String, ListedSpec> listed = sharedSpecsListedIn(text, sharedSpecs: sharedSpecs);
    // One finding per name: `has` and the read beside it look the same argument up twice.
    final Set<String> reported = <String>{};
    return <Finding>[
      for (final ArgumentRead read in argumentReadsIn(text, path))
        if (!writtenOut.contains(read.name) &&
            !listed.containsKey(read.name) &&
            reported.add(read.name))
          Finding(
            path,
            'reads the argument "${read.name}" and declares it nowhere — a value is delivered '
            'only under a declared name, so the read answers as if no row had written it and '
            'the step quietly does without',
            line: read.line,
          ),
      for (final PortCall call in portCallsIn(text, path))
        if (!call.carriesElevation)
          Finding(
            path,
            'carries the elevation a row may grant and does not pass it to this '
            '${call.method} call — ${_whatItCosts(call.port)}',
            line: call.line,
          ),
    ];
  }
}

/// What a dropped elevation does at [port], in the words a reader decides from.
String _whatItCosts(Port port) => switch (port) {
  Port.files => 'the call acts as the account the run started as, whatever the row said',
  Port.shell =>
    'the command runs as the account the run started as, whatever the row said — and a tool that '
        'refuses that account very often writes the refusal on its output and exits zero',
};

/// The argument reads of [text], with the line each sits on.
///
/// A read is `arguments.<method>('name')` with the name written out — the six methods the
/// framework's argument surface has. A name built out of pieces is not seen, and is one of the
/// stated limits.
List<ArgumentRead> argumentReadsIn(String text, String path) => <ArgumentRead>[
  for (final RegExpMatch match in _argumentRead.allMatches(text))
    ArgumentRead(path: path, line: lineAt(text, match.start), name: match.group(1)!),
];

/// The calls of [text] an elevation stands over, or none where no elevation stands anywhere in it.
///
/// A call no elevation reaches owes it to nobody, so it is not judged and not counted. Each call is
/// read to its closing bracket by counting brackets, and the elevation is looked for only among the
/// call's own arguments — never inside a nested call's.
List<PortCall> portCallsIn(String text, String path) {
  final List<_ElevationScope> scopes = _elevationScopesIn(text);
  if (scopes.isEmpty) {
    return const <PortCall>[];
  }
  return <PortCall>[
    for (final RegExpMatch match in _filesPortCall.allMatches(text))
      if (_covered(scopes, match.start))
        _callAt(text, path, match, port: Port.files, method: match.group(1)!),
    for (final RegExpMatch match in _commandComposed.allMatches(text))
      if (_covered(scopes, match.start))
        _callAt(text, path, match, port: Port.shell, method: 'Command${match.group(1) ?? ''}'),
  ];
}

/// A region of a file an elevation stands over, so a call inside it has one to pass on.
final class _ElevationScope {
  /// Records the region from [start] to [end], the second being the offset just past it.
  const _ElevationScope({required this.start, required this.end});

  /// The offset the region begins at.
  final int start;

  /// The offset just past the region's last character.
  final int end;

  /// Whether [offset] sits inside this region.
  bool covers(int offset) => offset >= start && offset < end;
}

/// The regions of [text] an elevation stands over.
///
/// A file that writes the elevation FIELD is one region, the whole of it: the field belongs to the
/// step, and every call the file makes is a call of that step. A file that carries the elevation in
/// a PARAMETER gets one region per such function — the function's own body — because the value
/// exists only there, and a function written beside it has none to pass. A function that declares
/// the parameter and carries no body at all is no region: an interface method and a redirecting
/// constructor make no call.
List<_ElevationScope> _elevationScopesIn(String text) {
  if (text.contains(elevationField)) {
    return <_ElevationScope>[_ElevationScope(start: 0, end: text.length)];
  }
  return <_ElevationScope>[
    for (int i = 0; i < text.length; i++)
      if (text[i] == '(' && _elevationParameter.hasMatch(_ownArgumentsOf(text, i)))
        if (_bodyAfter(text, i) case final _ElevationScope body) body,
  ];
}

/// Whether any of [scopes] stands over [offset].
bool _covered(List<_ElevationScope> scopes, int offset) =>
    scopes.any((_ElevationScope scope) => scope.covers(offset));

/// The body of the function whose parameter list opens at [openBracket], or null where it has none.
///
/// What may stand between the parameter list and the body is whitespace and the words a Dart
/// function marks its own kind with; then the body is either a block or an arrow expression, and
/// each is read to its own end by counting brackets. A parameter list followed by anything else
/// belongs to a declaration that makes no call of its own — an interface method, or a constructor
/// redirecting to another.
_ElevationScope? _bodyAfter(String text, int openBracket) {
  final int afterParameters = openBracket + balancedFrom(text, openBracket).length;
  final Match? opening = _bodyOpening.matchAsPrefix(text, afterParameters);
  if (opening == null) {
    return null;
  }
  final int start = opening.end - opening.group(1)!.length;
  return _ElevationScope(
    start: start,
    end: opening.group(1) == '{' ? _endOfBlock(text, start) : _endOfExpression(text, start),
  );
}

/// The offset just past the block that opens at [openBrace].
int _endOfBlock(String text, int openBrace) {
  int depth = 0;
  for (int i = openBrace; i < text.length; i++) {
    if (text[i] == '{') {
      depth++;
    } else if (text[i] == '}') {
      depth--;
      if (depth == 0) {
        return i + 1;
      }
    }
  }
  return text.length;
}

/// The offset just past the arrow expression that begins at [arrow].
///
/// It ends at the semicolon that closes the declaration, and a semicolon inside a bracket of the
/// expression's own — a statement of a closure it hands somewhere — belongs to that bracket.
int _endOfExpression(String text, int arrow) {
  int depth = 0;
  for (int i = arrow; i < text.length; i++) {
    final String char = text[i];
    if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      depth--;
    } else if (char == ';' && depth <= 0) {
      return i + 1;
    }
  }
  return text.length;
}

/// What may stand between a parameter list and the body it belongs to, with the body's own opening
/// captured.
final RegExp _bodyOpening = RegExp(r'\s*(?:async\*?|sync\*)?\s*(\{|=>)');

/// The elevation standing in a parameter list, which is the other way a file carries it.
///
/// Written without `required` and without a default, so all three spellings a parameter has —
/// `bool elevated`, `required bool elevated` and `bool elevated = false` — are the same declaration
/// here. It is looked for only among a bracket pair's OWN arguments, so [elevationField] itself can
/// never match it: a field stands in a class body and never inside brackets.
final RegExp _elevationParameter = RegExp(r'(?<![\w$])bool\s+elevated(?![\w$])');

/// The call [match] opens, read to its closing bracket.
PortCall _callAt(
  String text,
  String path,
  RegExpMatch match, {
  required Port port,
  required String method,
}) => PortCall(
  path: path,
  line: lineAt(text, match.start),
  port: port,
  method: method,
  carriesElevation: _elevatedWord.hasMatch(_ownArgumentsOf(text, match.end - 1)),
);

/// A read on the framework's argument surface, longest method name first so none shadows another.
final RegExp _argumentRead = RegExp(
  r"\barguments\.(?:optionalText|textList|integer|text|flag|has)\(\s*'([a-z][a-z0-9_]*)'",
);

/// A call on the files port, with the method it names captured.
final RegExp _filesPortCall = RegExp(
  r'\bcontext\.files\.(exists|read|write|delete|createDirectory|list)\(',
);

/// A command being composed, with the constructor it names captured.
///
/// The bare `Command(` is one of them, and a file carrying the elevation that uses it has dropped
/// the elevation by choosing it: that constructor takes no elevation at all and fixes it to false.
final RegExp _commandComposed = RegExp(r'\bCommand(\.detailed|\.observing)?\(');

/// The elevation standing as its own word, so a longer name that merely contains it is none.
final RegExp _elevatedWord = RegExp(r'(?<![\w$])elevated(?![\w$])');

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
