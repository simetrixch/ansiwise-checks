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
/// **A REGION IS FOUND BY COUNTING BRACES, so it is counted over [codeOf] and never over the file
/// as written.** A brace inside a doc comment or inside a string is not a brace of the program, and
/// a scan that counts one gets the region wrong in both directions: too far, and it reports the
/// function written below with nothing to pass; too short, and it stops judging while still
/// counting the file among those it judged. The second is the worse one, because the only thing it
/// changes on the screen is a number that now means less than it says. Where a body does not close
/// at all, no region is claimed — a region ending at the end of the file is a guess, and this scan
/// does not make one.
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
/// **What this cannot do, said plainly.** It is a text scan.
///
/// The first hop reads the file AS WRITTEN, comments included: it sees only reads written literally
/// as `arguments.<method>('name')`, takes any bare mention of a shared spec's identifier as a
/// declaration wherever in the file it stands — a doc comment naming one included — and resolves an
/// identifier declared outside the scanned tree only where [frameworkSharedSpecs] names it.
///
/// The second hop reads [codeOf] instead, so nothing written in a comment or inside a string is a
/// call, a bracket or a brace to it. Within that, it sees only calls written literally on
/// `context.files` and commands written literally as `Command(...)`, and sees an elevation standing
/// over a call only as the field written exactly as [elevationField] or as a parameter written
/// exactly as `bool elevated`. A command handed to `run` as a variable is not followed, and neither
/// is the value itself: a helper the step hands the elevation to is judged on its own parameter,
/// never on the call that fills it, so a caller passing the wrong answer is a thing this scan
/// cannot see. `elevated` written out among a call's own arguments counts as passing it whatever it
/// is set to, so a call that decides the question on purpose reads the same as one that carries the
/// row's answer.
///
/// It is a good sample rather than a proof, and both of the failures above are exactly the shape it
/// catches.
library;

import 'argument_specs.dart';
import 'dart_code.dart';
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
  ///
  /// A file counts here on exactly the ground that puts a call of it under [calls], so the two
  /// numbers are always read off the same population.
  List<String> get elevationCarriers => <String>[
    for (final String path in files)
      if (_elevationScopesIn(codeOf(tree.textOf(path) ?? '')).isNotEmpty) path,
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
///
/// Every bracket counted here is counted over [codeOf] rather than over [text], so a brace or a
/// bracket standing in a comment or in a string literal is none. A line in the answer of [codeOf]
/// is the same line as in [text], which is why a finding still names the place a reader opens.
List<PortCall> portCallsIn(String text, String path) {
  final String code = codeOf(text);
  final List<_ElevationScope> scopes = _elevationScopesIn(code);
  if (scopes.isEmpty) {
    return const <PortCall>[];
  }
  return <PortCall>[
    for (final RegExpMatch match in _filesPortCall.allMatches(code))
      if (_covered(scopes, match.start))
        _callAt(code, path, match, port: Port.files, method: match.group(1)!),
    for (final RegExpMatch match in _commandComposed.allMatches(code))
      if (_covered(scopes, match.start))
        _callAt(code, path, match, port: Port.shell, method: 'Command${match.group(1) ?? ''}'),
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

/// The regions of [code] an elevation stands over, over the answer of [codeOf] rather than over a
/// file's raw text.
///
/// A file that writes the elevation FIELD is one region, the whole of it: the field belongs to the
/// step, and every call the file makes is a call of that step. A file that carries the elevation in
/// a PARAMETER gets one region per such function — the function's own body — because the value
/// exists only there, and a function written beside it has none to pass. A function that declares
/// the parameter and carries no body at all is no region: an interface method and a redirecting
/// constructor make no call.
///
/// **A region whose end is not in the file is not a region.** Where the body does not close, the
/// scan does not know where the elevation stops, and a region running to the end of the file would
/// put every call written below it under an elevation that ended somewhere above. So nothing is
/// claimed, and the function contributes neither a call to judge nor a reason to count its file
/// among the carriers.
List<_ElevationScope> _elevationScopesIn(String code) {
  if (code.contains(elevationField)) {
    return <_ElevationScope>[_ElevationScope(start: 0, end: code.length)];
  }
  return <_ElevationScope>[
    for (final RegExpMatch match in _elevationParameter.allMatches(code))
      if (_enclosingBracket(code, match.start) case final int openBracket)
        if (_bodyAfter(code, openBracket) case final _ElevationScope body) body,
  ];
}

/// Whether any of [scopes] stands over [offset].
bool _covered(List<_ElevationScope> scopes, int offset) =>
    scopes.any((_ElevationScope scope) => scope.covers(offset));

/// The bracket whose OWN arguments [offset] stands among, or null where it stands in none.
///
/// Read backwards, so a nested bracket pair closes before it opens and the walk steps over it
/// whole. That is the same "own arguments" [_ownArgumentsOf] reads forwards, and it is what keeps
/// a `bool elevated` written as a local or as a field from being taken for a parameter: nothing
/// encloses it, so the walk reaches the start of the file and answers null.
int? _enclosingBracket(String code, int offset) {
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

/// The body of the function whose parameter list opens at [openBracket], or null where it has none
/// or where its end is not in [code].
///
/// What may stand between the parameter list and the body is whitespace, the words a Dart function
/// marks its own kind with, and a constructor's initializer list; then the body is either a block
/// or an arrow expression, and each is read to its own end by counting brackets. A parameter list
/// followed by anything else belongs to a declaration that makes no call of its own — an interface
/// method, or a constructor redirecting to another.
_ElevationScope? _bodyAfter(String code, int openBracket) {
  final int afterParameters = openBracket + balancedFrom(code, openBracket).length;
  final int? opening = _bodyOpeningAfter(code, afterParameters);
  if (opening == null) {
    return null;
  }
  final int? end = code.startsWith('{', opening)
      ? _endOfBlock(code, opening)
      : _endOfExpression(code, opening);
  return end == null ? null : _ElevationScope(start: opening, end: end);
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
      final int? close = _endOfBlock(code, i);
      if (close == null) {
        return null;
      }
      final int next = _pastWhitespace(code, close);
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

/// The offset of the first character from [from] that is not whitespace, or the end of [code].
int _pastWhitespace(String code, int from) {
  int at = from;
  while (at < code.length && _whitespace.hasMatch(code[at])) {
    at++;
  }
  return at;
}

/// The offset just past the block that opens at [openBrace], or null where it does not close.
int? _endOfBlock(String code, int openBrace) {
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

/// The offset just past the arrow expression that begins at [arrow], or null where it does not end.
///
/// It ends at the semicolon that closes the declaration, and a semicolon inside a bracket of the
/// expression's own — a statement of a closure it hands somewhere — belongs to that bracket.
int? _endOfExpression(String code, int arrow) {
  int depth = 0;
  for (int i = arrow; i < code.length; i++) {
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

/// The elevation standing in a parameter list, which is the other way a file carries it.
///
/// Written without `required` and without a default, so all three spellings a parameter has —
/// `bool elevated`, `required bool elevated` and `bool elevated = false` — are the same declaration
/// here. A match counts only where a bracket pair encloses it as one of its OWN arguments, so
/// [elevationField] itself can never be one: a field stands in a class body and never inside
/// brackets.
final RegExp _elevationParameter = RegExp(r'(?<![\w$])bool\s+elevated(?![\w$])');

/// The call [match] opens in [code], read to its closing bracket.
PortCall _callAt(
  String code,
  String path,
  RegExpMatch match, {
  required Port port,
  required String method,
}) => PortCall(
  path: path,
  line: lineAt(code, match.start),
  port: port,
  method: method,
  carriesElevation: _elevatedWord.hasMatch(_ownArgumentsOf(code, match.end - 1)),
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
///
/// [code] is the answer of [codeOf] and not a file's raw text. A bracket inside a string argument —
/// a shell fragment such as `'echo )'` — would otherwise end the call early and hide the elevation
/// standing after it, and its mirror `'echo ('` would carry the region into the NEXT call and take
/// that call's elevation for this one's.
String _ownArgumentsOf(String code, int openBracket) {
  final StringBuffer own = StringBuffer();
  int depth = 1;
  for (int i = openBracket + 1; i < code.length; i++) {
    final String char = code[i];
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
