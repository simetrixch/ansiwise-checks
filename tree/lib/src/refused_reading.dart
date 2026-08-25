/// refused-reading — a step never answers SATISFIED on a reading that was refused.
///
/// **THE SHAPE, and it has cost this platform three outages.** A reading that COULD NOT BE TAKEN is
/// turned into an answer. "The operating system refused me", "the tool did not answer", "the command
/// exited non-zero" come back looking exactly like "there is nothing there", and the code reads the
/// first as the second. One measurement folded three refused readings into the `null` that means
/// "this machine steers nothing"; eight steps hung off it and all eight then answered Satisfied over
/// a machine nobody had measured, including the one whose whole purpose is proving a network drop-in
/// merged. A step that measured the host's packet-filtering backend, refused, answered "nothing to
/// do", and half of all outbound pod traffic was lost.
///
/// **What is judged is the SATISFIED, not the fold.** A refusal folded into a value is not wrong by
/// itself, and a scan saying it is would report about twenty places at once — a presence test whose
/// refusal means "the thing is missing" leads to MORE work and never to a false done, and the exit
/// code of `test -L` or of `command -v` really is that command's answer. Those are the places a
/// reader cannot fix, and a scan that names them is a scan that gets switched off. What no reading
/// may reach is `CheckResult.satisfied`: the engine stamps a satisfied observing row PROVEN, so that
/// branch is the run telling the operator that a machine was measured and found in the state the
/// step produces. A refusal arriving there is the software saying a thing that is not so.
///
/// **The refusal is FOLLOWED, because it never arrives in one hop.** In the measurement above the
/// refused `ip` sat in `_defaultRoutes`, which answered an empty list; the empty list became the
/// `null` of `measure`; and `check` answered satisfied on that null. A scan reading only the branch
/// the refusal opens would have been green on all three. So a declaration that answers a BARE value
/// — `null`, `false`, `true`, the empty string, an empty collection — on a branch a refusal reaches
/// carries the refusal in that value, and a declaration of the same file that tests another one's
/// answer against exactly that value carries it one hop further. The chain is run to a fixed point
/// and named in the finding, so the reader is handed the whole way from the command to the claim.
///
/// **A value that NAMES the refusal ends the chain, which is the whole of the house treatment.** A
/// branch that throws, that answers `CheckResult.blocked`, that answers a `_Unit.unreadable` or an
/// `UpstreamReading.unresolved`, or that answers a record carrying a `refusal` field, hands the
/// caller something it cannot mistake for a reading that was taken — so nothing travels on and
/// nothing is reported. That is not a special case in the scan: none of those is a bare value.
///
/// **BRACES ARE COUNTED OVER [codeOf] AND NEVER OVER THE FILE AS WRITTEN.** A brace inside a doc
/// comment or a string literal is not a brace of the program. Counting one runs a region past the
/// branch it belongs to and reports the code written below, and its mirror ends a region early — so
/// the branch that really folds the refusal is never judged while the file goes on being counted
/// among the files this scan judged. The second is the worse one, because the only thing it changes
/// on the screen is a number that now means less than it says.
///
/// **What this cannot do, said plainly. It is a text scan, and these are the sites it does not
/// reach.**
///
/// THE FILES PORT IS NOT JUDGED AT ALL. `Files.exists` with no elevation is `File(path).exists()`,
/// which answers false for a directory this run cannot enter exactly as it answers false for a file
/// that is not there — the same folded reading, one level down, in the port rather than in the step.
/// Every step in the tree asks it, so judging it would name a hundred places whose only fix is in
/// the framework. It is a hole and it is named here rather than left to be discovered.
///
/// A refusal is seen only where the code writes `!<name>.ok` on a value the same declaration holds
/// as one of [readingTypes], or where a `return` hands the else half of a ternary whose condition
/// reads that value's `ok`. An `ok` tested the other way round with an `else`, a `switch`, a `case`
/// pattern, or an exit code compared by number is not seen.
///
/// The chain is followed only INSIDE ONE FILE and only through a declaration that carries a
/// parameter list and a body. A getter has no parameter list, so a refusal folded into one is not
/// followed; a value handed across a file boundary is not followed either. A branch answering the
/// result of a CALL rather than a literal ends the chain, so a helper that hands the bare value on
/// hides it from here.
///
/// The one hop is read off a name a declaration BINDS, or off a call written in the condition
/// itself. `n == null`, `!n`, `n.isEmpty` and a condition that is nothing but `n` are the four
/// tests it understands; anything else is a branch it does not know the refusal reaches.
///
/// It is a good sample rather than a proof, and the measurement that cost the eight satisfied rows
/// is exactly the shape it catches.
library;

import 'argument_specs.dart';
import 'dart_body.dart';
import 'dart_code.dart';
import 'finding.dart';
import 'source_tree.dart';
import 'word_purity.dart';

/// The types a step holds a reading of the machine in, before anything has asked whether the
/// reading was taken.
///
/// Both carry the same trap: the value is there either way, and only `ok` says which of the two it
/// is. Named one at a time rather than matched by a pattern, so a third port is a decision somebody
/// makes here.
const List<String> readingTypes = <String>['CommandResult', 'HttpAnswer'];

/// What the framework stamps PROVEN, and therefore the one answer no refusal may reach.
const String satisfiedAnswer = 'CheckResult.satisfied';

/// The value a refusal is folded into, named by what a caller has to write to tell it apart.
///
/// These four are the whole of what a bare answer can be, and each of them is also a value a
/// reading that WAS taken can produce — which is the defect in one word.
enum FoldedAnswer {
  /// `null`, told apart by `== null`.
  nothing,

  /// `false`, told apart by `!`.
  no,

  /// `true`, told apart by standing alone in a condition.
  yes,

  /// The empty string or an empty collection, told apart by `isEmpty`.
  empty,
}

/// One reading of the machine a file holds.
///
/// This is the denominator of the whole scan: a file holding none of these makes no reading, and a
/// run in which the total is zero looked at nothing.
final class Reading {
  /// Records that [path] holds a [type] called [name] at [line].
  const Reading({required this.path, required this.line, required this.name, required this.type});

  /// The repository-relative file it stands in.
  final String path;

  /// The line it is bound on, counted from one.
  final int line;

  /// The name it is bound to.
  final String name;

  /// Which of [readingTypes] it is.
  final String type;
}

/// One branch a refused reading reaches, and the way it got there.
final class Refusal {
  /// Records the branch [path] holds at [line], reached [through] the declarations named.
  const Refusal({required this.path, required this.line, required this.through});

  /// The repository-relative file it stands in.
  final String path;

  /// The line the branch opens on, counted from one.
  final int line;

  /// The declarations the refusal travelled through, the one that made the reading first.
  ///
  /// A single name is a branch standing beside the reading itself; more than one is a value the
  /// refusal was folded into and carried on in.
  final List<String> through;
}

/// One `CheckResult.satisfied` a file writes.
///
/// Stated as its own number because it is the population this rule is about: a tree that answers
/// satisfied nowhere is a tree this scan decided nothing over, and that reads exactly like a tree
/// it found clean.
final class SatisfiedAnswer {
  /// Records the answer [path] writes at [line], [insideDeclaration] saying whether this scan
  /// could reach it at all.
  const SatisfiedAnswer({required this.path, required this.line, required this.insideDeclaration});

  /// The repository-relative file it stands in.
  final String path;

  /// The line it is written on, counted from one.
  final int line;

  /// Whether it stands inside the body of a declaration this scan found.
  ///
  /// The chain a refusal travels is followed inside those bodies and nowhere else, so an answer in
  /// none of them is an answer nothing judged. It is stated rather than dropped, because a reader
  /// that stopped recognising a shape of declaration would make every tree come back clean and
  /// change nothing on the screen but a number.
  final bool insideDeclaration;
}

/// Every satisfied answer a refused reading reaches, in the files of [scanned].
final class RefusedReading {
  /// Judges the Dart files of [tree] under [scanned].
  const RefusedReading({required this.tree, required this.scanned});

  /// The tree the files are read from.
  final SourceTree tree;

  /// The directories read, named one at a time so that widening the scan is a decision.
  final List<String> scanned;

  /// The Dart files judged, which is what every count below is stated against.
  List<String> get files => <String>[
    for (final String path in scannedFilesOf(tree, scanned))
      if (path.endsWith('.dart')) path,
  ];

  /// Every reading of the machine the judged files hold.
  List<Reading> get readings => <Reading>[
    for (final String path in files) ..._judge(tree.textOf(path) ?? '', path).readings,
  ];

  /// Every branch a refused reading reaches, whether it was reported or not.
  List<Refusal> get refusals => <Refusal>[
    for (final String path in files) ..._judge(tree.textOf(path) ?? '', path).refusals,
  ];

  /// Every satisfied answer the judged files write.
  List<SatisfiedAnswer> get answers => <SatisfiedAnswer>[
    for (final String path in files) ..._judge(tree.textOf(path) ?? '', path).answers,
  ];

  /// Every satisfied answer a refused reading reaches.
  List<Finding> get findings => <Finding>[
    for (final String path in files) ..._judge(tree.textOf(path) ?? '', path).findings,
  ];

  /// The findings of one file's [text], for a probe that plants a single file.
  static List<Finding> findingsIn(String text, String path) => _judge(text, path).findings;

  /// Everything one file's [text] answers, for a probe that states coverage as well as findings.
  static ({
    List<Reading> readings,
    List<Refusal> refusals,
    List<SatisfiedAnswer> answers,
    List<Finding> findings,
  })
  judgementOf(String text, String path) {
    final _Judgement judged = _judge(text, path);
    return (
      readings: judged.readings,
      refusals: judged.refusals,
      answers: judged.answers,
      findings: judged.findings,
    );
  }
}

/// What one file answered.
final class _Judgement {
  const _Judgement({
    required this.readings,
    required this.refusals,
    required this.answers,
    required this.findings,
  });

  final List<Reading> readings;
  final List<Refusal> refusals;
  final List<SatisfiedAnswer> answers;
  final List<Finding> findings;
}

/// One branch a refusal reaches, and the way it got there.
final class _Reached {
  const _Reached({required this.region, required this.readingLine, required this.through});

  /// The branch itself — a block, a statement, or the else half of a ternary.
  final CodeRegion region;

  /// The line the reading that was refused is tested on.
  final int readingLine;

  /// The declarations the refusal travelled through, the one holding the reading first.
  final List<String> through;
}

/// One value a declaration answers on a branch a refusal reaches.
final class _Fold {
  const _Fold({required this.answer, required this.readingLine, required this.through});

  final FoldedAnswer answer;
  final int readingLine;
  final List<String> through;
}

/// Judges one file, over [codeOf] rather than over the text as written.
_Judgement _judge(String text, String path) {
  final String code = codeOf(text);
  final List<DartDeclaration> declarations = declarationsIn(code);

  final List<Reading> readings = <Reading>[
    for (final RegExpMatch match in _readingHeld.allMatches(code))
      Reading(
        path: path,
        line: lineAt(code, match.start),
        name: match.group(2)!,
        type: match.group(1)!,
      ),
  ];
  final List<SatisfiedAnswer> answers = <SatisfiedAnswer>[
    for (final RegExpMatch match in _satisfied.allMatches(code))
      SatisfiedAnswer(
        path: path,
        line: lineAt(code, match.start),
        insideDeclaration: declarations.any(
          (DartDeclaration each) => each.body.covers(match.start),
        ),
      ),
  ];

  // The chain is run to a fixed point BEFORE anything is reported, so a finding is never raised
  // twice and a declaration that only becomes a carrier in the third round still carries when the
  // reporting pass reads it. One round per declaration is the most any chain can need, since each
  // round makes at least one declaration a carrier or the answer has stopped moving.
  final Map<String, List<_Fold>> folds = <String, List<_Fold>>{};
  for (int round = 0; round <= declarations.length; round++) {
    bool moved = false;
    for (final DartDeclaration declaration in declarations) {
      for (final _Reached reached in _reachedIn(code, declaration, folds)) {
        final FoldedAnswer? answer = answeredIn(code, reached.region);
        if (answer == null) {
          continue;
        }
        moved =
            _remember(
              folds,
              declaration.name,
              _Fold(
                answer: answer,
                readingLine: reached.readingLine,
                through: <String>[...reached.through, declaration.name],
              ),
            ) ||
            moved;
      }
    }
    if (!moved) {
      break;
    }
  }

  final List<Refusal> refusals = <Refusal>[];
  final List<Finding> found = <Finding>[];
  for (final DartDeclaration declaration in declarations) {
    for (final _Reached reached in _reachedIn(code, declaration, folds)) {
      refusals.add(
        Refusal(
          path: path,
          line: lineAt(code, reached.region.start),
          through: <String>[...reached.through, declaration.name],
        ),
      );
      for (final RegExpMatch match in _satisfied.allMatches(
        code.substring(reached.region.start, reached.region.end),
      )) {
        found.add(
          Finding(
            path,
            'answers satisfied on a reading that was refused: ${_wayThrough(reached)}. A satisfied '
            'observing row is stamped PROVEN, so this reports a machine in the state the step '
            'produces over a machine nobody could read — the fix is to say the reading was not '
            'taken, by throwing or by answering a value that names the refusal',
            line: lineAt(code, reached.region.start + match.start),
          ),
        );
      }
    }
  }

  return _Judgement(
    readings: readings,
    refusals: refusals,
    answers: answers,
    findings: _withoutRepeats(found),
  );
}

/// The way a refusal took to [reached], in the words a reader follows back to the command.
String _wayThrough(_Reached reached) {
  final String where = 'the reading refused at line ${reached.readingLine}';
  if (reached.through.isEmpty) {
    return '$where opens this branch';
  }
  return '$where is folded into a value by ${reached.through.join(', carried on by ')}, and this '
      'branch reads that value as an answer';
}

/// [found] with a second finding about the same place left out.
///
/// One branch can be reached by two chains of the same refusal, and a reader fixing the place fixes
/// both. The count is what an audit states, so a place counted twice overstates what is wrong.
List<Finding> _withoutRepeats(List<Finding> found) {
  final Set<String> seen = <String>{};
  return <Finding>[
    for (final Finding finding in found)
      if (seen.add('${finding.subject}:${finding.line}')) finding,
  ];
}

/// Records [fold] against [name] and answers whether it was new.
///
/// One fold per [FoldedAnswer] and the FIRST chain that reached it kept, because a later chain to
/// the same value is a longer way to say the same thing — and keeping both would never let the loop
/// below settle.
bool _remember(Map<String, List<_Fold>> folds, String name, _Fold fold) {
  final List<_Fold> known = folds.putIfAbsent(name, () => <_Fold>[]);
  if (known.any((_Fold each) => each.answer == fold.answer)) {
    return false;
  }
  known.add(fold);
  return true;
}

/// Every branch a refusal reaches inside [declaration], given what the file's declarations are
/// known to fold so far.
List<_Reached> _reachedIn(
  String code,
  DartDeclaration declaration,
  Map<String, List<_Fold>> folds,
) {
  final String body = code.substring(declaration.body.start, declaration.body.end);
  final int base = declaration.body.start;
  // The parameter list is read for the readings and the body for everything else, because a
  // declaration HOLDS a reading it was handed exactly as it holds one it assigned.
  final Set<String> held = readingNamesIn(
    code.substring(declaration.parameters.start, declaration.body.end),
  );
  final Map<String, String> bound = <String, String>{
    for (final RegExpMatch match in _boundToCall.allMatches(body)) match.group(1)!: match.group(2)!,
  };

  final List<_Reached> reached = <_Reached>[
    ..._reachedByCondition(code, base, body, held, bound, folds),
    ..._reachedByTernary(code, base, body, held),
  ];
  return reached;
}

/// The branches an `if` of [body] opens that a refusal reaches.
List<_Reached> _reachedByCondition(
  String code,
  int base,
  String body,
  Set<String> held,
  Map<String, String> bound,
  Map<String, List<_Fold>> folds,
) {
  final List<_Reached> reached = <_Reached>[];
  for (final RegExpMatch opening in ifOpening.allMatches(body)) {
    final int openBracket = opening.end - 1;
    final String whole = balancedFrom(body, openBracket);
    if (whole.length < 2) {
      continue;
    }
    final String condition = whole.substring(1, whole.length - 1);
    final CodeRegion? guarded = guardedAfter(code, base + openBracket + whole.length);
    if (guarded == null) {
      continue;
    }
    final int line = lineAt(code, base + opening.start);

    // The reading this declaration holds itself, asked whether it answered.
    for (final String name in held) {
      if (refusesIn(condition, name)) {
        reached.add(_Reached(region: guarded, readingLine: line, through: const <String>[]));
      }
    }

    // A value another declaration of this file folds a refusal into, tested against exactly that
    // value. Both spellings are read: the answer bound to a name first, and the call written in the
    // condition itself, which is how the shortest of these are written.
    for (final MapEntry<String, String> each in bound.entries) {
      for (final _Fold fold in folds[each.value] ?? const <_Fold>[]) {
        if (_selects(condition, each.key, fold.answer)) {
          reached.add(
            _Reached(region: guarded, readingLine: fold.readingLine, through: fold.through),
          );
        }
      }
    }
    for (final MapEntry<String, List<_Fold>> each in folds.entries) {
      for (final _Fold fold in each.value) {
        if (_selectsCall(condition, each.key, fold.answer)) {
          reached.add(
            _Reached(region: guarded, readingLine: fold.readingLine, through: fold.through),
          );
        }
      }
    }
  }
  return reached;
}

/// The else halves of [body]'s returned ternaries whose condition asks a held reading whether it
/// answered.
///
/// `return answer.ok && answer.trimmed.isNotEmpty ? answer.trimmed : null;` is the same fold
/// written as one expression, and a scan reading only `if` statements would be blind to it.
List<_Reached> _reachedByTernary(String code, int base, String body, Set<String> held) {
  final List<_Reached> reached = <_Reached>[];
  for (final RegExpMatch opening in returnOpening.allMatches(body)) {
    final int? end = endOfExpression(body, opening.start);
    if (end == null) {
      continue;
    }
    final String statement = body.substring(opening.end, end - 1);
    final int? question = topLevelAt(statement, '?');
    if (question == null) {
      continue;
    }
    final int? colon = topLevelAt(statement, ':', from: question + 1);
    if (colon == null) {
      continue;
    }
    final String condition = statement.substring(0, question);
    if (!held.any((String name) => asksOk(condition, name))) {
      continue;
    }
    reached.add(
      _Reached(
        region: CodeRegion(start: base + opening.end + colon + 1, end: base + end - 1),
        readingLine: lineAt(code, base + opening.start),
        through: const <String>[],
      ),
    );
  }
  return reached;
}

/// The value [region] answers, or null where it answers something that is not a bare value.
///
/// A branch that throws, that answers a refusal the framework carries, or that hands back anything
/// built out of the refusal's own words answers no bare value — so nothing travels on from it, and
/// that is the whole of the house treatment as this scan sees it.
FoldedAnswer? answeredIn(String code, CodeRegion region) {
  final String inside = code.substring(region.start, region.end);
  final RegExpMatch? returned = returnOpening.firstMatch(inside);
  final int? returnEnds = returned == null ? null : endOfExpression(inside, returned.start);
  if (returned != null && returnEnds == null) {
    return null;
  }
  final String answer = returned == null
      ? inside.trim()
      : inside.substring(returned.end, returnEnds! - 1).trim();
  final String bare = answer.startsWith('const ') ? answer.substring(6).trim() : answer;
  return switch (bare) {
    'null' => FoldedAnswer.nothing,
    'false' => FoldedAnswer.no,
    'true' => FoldedAnswer.yes,
    "''" || '""' => FoldedAnswer.empty,
    _ => _emptyCollection.hasMatch(bare) ? FoldedAnswer.empty : null,
  };
}

/// Whether [condition] asks [name] whether its reading was taken and takes the branch where it was
/// not.
bool refusesIn(String condition, String name) =>
    RegExp('!\\s*${RegExp.escape(name)}\\s*\\.\\s*ok(?![\\w\$])').hasMatch(condition);

/// Whether [condition] mentions [name]'s `ok` at all, which is what makes a ternary a fold.
bool asksOk(String condition, String name) =>
    RegExp('(?<![\\w\$])${RegExp.escape(name)}\\s*\\.\\s*ok(?![\\w\$])').hasMatch(condition);

/// Whether [condition] takes the branch [name] carries when it holds [answer].
bool _selects(String condition, String name, FoldedAnswer answer) {
  final String at = RegExp.escape(name);
  return switch (answer) {
    FoldedAnswer.nothing => RegExp('(?<![\\w\$])$at\\s*==\\s*null(?![\\w\$])').hasMatch(condition),
    FoldedAnswer.no => RegExp('!\\s*$at(?![\\w\$.])').hasMatch(condition),
    FoldedAnswer.yes => condition.trim() == name,
    FoldedAnswer.empty => RegExp(
      '(?<![\\w\$])$at\\s*\\.\\s*isEmpty(?![\\w\$])',
    ).hasMatch(condition),
  };
}

/// Whether [condition] calls [name] and takes the branch its [answer] leads to.
///
/// The call and the test are read as two facts of the same condition rather than paired by
/// position, so `a || !await present(path)` is a branch this refusal reaches — which it is,
/// whatever the other half of the condition said.
bool _selectsCall(String condition, String name, FoldedAnswer answer) {
  final String call = '(?<![\\w\$])${RegExp.escape(name)}\\s*\\(';
  if (!RegExp(call).hasMatch(condition)) {
    return false;
  }
  return switch (answer) {
    FoldedAnswer.nothing => condition.contains('== null'),
    FoldedAnswer.no => RegExp(
      '!\\s*(?:await\\s+)?(?:[\\w\$]+\\s*\\.\\s*)*$call',
    ).hasMatch(condition),
    FoldedAnswer.yes => false,
    FoldedAnswer.empty => condition.contains('.isEmpty'),
  };
}

/// A value of one of [readingTypes], bound to a name.
///
/// Every way a declaration comes to HOLD one is the same shape: a local it assigns, a field it
/// keeps, and a PARAMETER it is handed. The last is the one a pattern built around `=` misses, and
/// it is where a helper that decides what an answer SAYS takes it — so a scan wanting an assignment
/// counted no reading at all in the package whose whole surface is such a helper.
final RegExp _readingHeld = RegExp(
  '(?<![\\w\$])(?:final\\s+|late\\s+|const\\s+|required\\s+)*'
  '(${readingTypes.join('|')})\\??\\s+(?!(?:get|set|Function)(?![\\w\$]))'
  '([a-zA-Z_\$][\\w\$]*)\\s*(?==|;|,|\\)|\\{)',
);

/// A name bound to the answer of a call, with the call's own last name captured.
///
/// `==`, `!=`, `<=`, `>=` and `=>` are none of them an assignment, and each of them fails this
/// pattern at the character after the first `=`.
final RegExp _boundToCall = RegExp(
  r'(?<![\w$])([a-zA-Z_$][\w$]*)\s*=\s*(?:await\s+)?(?:[a-zA-Z_$][\w$]*\s*\.\s*)*'
  r'([a-zA-Z_$][\w$]*)\s*\(',
);

/// The names [code] binds a reading of the machine to.
///
/// Every way a declaration comes to HOLD one is here: a local it assigns, a field it keeps, and a
/// PARAMETER it is handed. It is read from ONE place so that every scan judging a refusal agrees on
/// what a reading is: two readers of this would agree on the day they were written and drift
/// afterwards, and the drift is silent, because a reader that stops recognising a reading makes its
/// scan come back clean.
Set<String> readingNamesIn(String code) => <String>{
  for (final RegExpMatch match in _readingHeld.allMatches(code)) match.group(2)!,
};

/// The framework's satisfied answer, however it is spelled.
final RegExp _satisfied = RegExp('(?<![\\w\$])${RegExp.escape(satisfiedAnswer)}\\s*\\(');

/// A collection literal with nothing in it, with or without the types it is written for.
final RegExp _emptyCollection = RegExp(r'^(?:<.*>)?(?:\[\s*\]|\{\s*\})$');
