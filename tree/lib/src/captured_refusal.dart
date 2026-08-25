/// captured-refusal — a capture never answers, on a reading that was refused, a value its undo
/// ACTS on.
///
/// **A CAPTURE HAS NO "MORE WORK" DIRECTION, and that is the whole argument for a second guard.**
/// The sibling rule beside this one holds that a refused reading never becomes a satisfied answer,
/// and it deliberately stays silent where a refusal folded into "the thing is missing" leads to MORE
/// work: there the cost is one unnecessary apply and never a green row over a machine nobody read.
/// A capture has no such half. Every value it answers is an INSTRUCTION to the undo — one half
/// leaves the machine as it stands, the other takes something away — and there is no third value
/// meaning "nobody read this". So a refusal folded here delays nothing; it issues the taking-away
/// over a machine nobody could read, and it does it while the engine is cleaning up after some OTHER
/// step failed, which is the worst moment to take an access away.
///
/// Three sites cost this platform exactly that, each closed by hand: a refused `id -G` answered
/// false and false was the half that ran `gpasswd --delete`; a refused read of a remote answered
/// false and false was the half that ran `push --delete` against a tag somebody else published; a
/// refused `get secret` answered "this run created it" and the undo deleted a credential every
/// workload reading it depends on.
///
/// **WHAT IS JUDGED IS THE PAIR, never the fold on its own.** A capture that folds a refusal into a
/// value its undo LEAVES ALONE is not wrong — it is the house treatment, and it is what all three
/// closed sites now do: answer the half that leaves the machine as it stands, and say out loud that
/// it is not a measurement. Judging the fold alone would report those three, which is the fastest
/// way to have a check switched off. So the rule reads the undo as well and asks one question: given
/// the value a refusal makes this capture answer, does the undo reach a port?
///
/// **How the undo is read.** Its own body, statement by statement, with the value in hand. A
/// statement standing before any test of the captured value runs whatever the capture answered, so
/// it carries no refusal and is stepped over — the merge a step aborts before it looks at what it
/// captured is the step cleaning up its own partial apply. A condition that does not mention the
/// captured value is stepped over whole for the same reason. What is left is the branch the VALUE
/// selects, and there two answers end the walk: a branch that reaches one of the three ports ACTS,
/// and a branch that returns without reaching one leaves the machine alone.
///
/// **A branch reaches a port through the undo's own context or through a declaration of the same
/// class, and the CALL IS FOLLOWED into that declaration's body rather than counted as a reach of
/// its own.** Counting it was a finding on the house treatment itself: the branch that leaves the
/// machine as it stands says so in a log line, and the log line composes the path with a helper of
/// the same class. A helper that reads an answer touches no port, and a branch touching none of the
/// three changes nothing, whatever else it writes.
///
/// **A refusal is the same thing both rules recognise, read from one place.** The types a reading
/// arrives in, what counts as a bare answer, and how a branch tests whether a reading was taken all
/// come from the sibling rule's own file. Two scans with private copies of that would agree on the
/// day they were written and drift afterwards, and the drift is silent: a reader that stops
/// recognising a refusal makes its scan come back clean.
///
/// **What this cannot do, said plainly. It is a text scan, and these are the sites it does not
/// reach.**
///
/// THE FILES PORT IS NOT JUDGED, AND THAT IS THE MEASURED DECISION OF THIS RULE RATHER THAN AN
/// OVERSIGHT. `Files.exists` with no elevation is one boolean with nothing beside it: it answers
/// false for a directory this run cannot enter exactly as it answers false for a file that is not
/// there. There is no `ok` to test, so the refusal and the answer are the SAME VALUE and no branch
/// exists in the text to point a reader at. Thirteen captures in the tree fold it, and they were
/// read one at a time: one is an empty capture that folds nothing, four answer a value their undo
/// leaves alone, and EIGHT answer a value their undo acts on. Those eight are real, and the fix for
/// every one of them is the same single change somewhere else — either the port learns to say that
/// it could not look, or each step asks the parent directory's listing instead, which throws when it
/// cannot be read. A rule reporting eight places whose one fix nobody can make from the finding is a
/// rule that gets switched off, and then it holds nothing at all. It is a hole, it is named here,
/// and the count is stated so that nobody has to rediscover it.
///
/// A REFUSAL IS SEEN ONLY WHERE THE CODE ASKS `ok`. `!<name>.ok` in a condition, the else half of a
/// ternary whose condition reads that value's `ok`, and an answer that IS `<name>.ok`. A reading
/// whose `ok` is never asked AT ALL is invisible here: `activate_public_src_routing` answers whether
/// the command's trimmed output equals a word, so a refused command's empty output reads as an
/// output that said something else. An exit code compared by number is invisible for the same
/// reason.
///
/// A BRANCH ANSWERING A CONSTRUCTOR RATHER THAN A BARE VALUE ENDS THE CHAIN, and that is right for
/// every type carrying a refusal of its own and wrong for one that does not. `git_push_credential`
/// answers a record of "no file and no helpers" on a refused reading, and its undo puts back exactly
/// the helpers that record names — which is none. The same hole stands in the sibling rule, and
/// closing it would mean deciding which named types carry a refusal, which is a decision no text
/// scan can make.
///
/// THE CHAIN IS FOLLOWED ONLY WHERE ONE DECLARATION HANDS ANOTHER'S ANSWER STRAIGHT BACK, inside
/// the same class of the same file. That reaches a capture written as one call, and a capture that
/// refuses one thing itself and asks a helper about another. A capture that TRANSFORMS what it was
/// handed carries the refusal just as far, and this scan does not follow it there: `create_group`
/// compares the answer against null, `enable_service` reads a field off it, `tailnet_leave` and
/// `tailnet_reconnect` test it against a constant. Reading those would mean evaluating expressions
/// rather than recognising shapes. A value bound to a local and answered on the line below is not
/// followed either, and neither is a call that leaves the file — `install_tailscale_client` asks
/// another step's declaration, and the whole `contentBefore` family asks a shared one.
///
/// A CLASS THAT HOLDS MORE THAN ONE CAPTURE OR MORE THAN ONE UNDO IS NOT JUDGED, because which
/// undo a capture instructs would then be a guess. So is a pair whose undo tests the captured value
/// in a shape this scan cannot decide, and so is one whose undo chains a second condition onto the
/// first with `else if`. Each of those is COUNTED and named rather than left to look like a clean
/// answer.
library;

import 'argument_specs.dart';
import 'dart_body.dart';
import 'dart_code.dart';
import 'finding.dart';
import 'refused_reading.dart';
import 'source_tree.dart';
import 'word_purity.dart';

/// What a step is called that reads the machine before it changes it, and what it is called that
/// puts the machine back.
///
/// Named one at a time rather than derived, so a framework that renames either half is a decision
/// somebody makes here instead of a scan that quietly stops finding anything.
const String captureName = 'capture';

/// See [captureName].
const String undoName = 'undo';

/// The three ways this framework reaches outside a step, and therefore the whole of what an undo can
/// DO to a machine.
///
/// A branch touching none of them changes nothing, whatever else it writes — which is what lets a
/// branch that logs the refusal and returns count as leaving the machine alone.
const List<String> portNames = <String>['shell', 'files', 'http'];

/// One capture and the undo it hands its answer to.
///
/// This is the denominator of the whole scan: a file holding none of these makes no instruction, and
/// a run in which the total is zero looked at nothing.
final class Capture {
  /// Records the capture [path] holds at [line], inside [step], whose undo stands at [undoLine].
  const Capture({
    required this.path,
    required this.line,
    required this.step,
    required this.undoLine,
  });

  /// The repository-relative file it stands in.
  final String path;

  /// The line the capture is declared on, counted from one.
  final int line;

  /// The class both halves stand in.
  final String step;

  /// The line the undo is declared on, counted from one.
  final int undoLine;
}

/// One value a capture answers when a reading it rests on was refused, and what its undo does with
/// that value.
final class Instruction {
  /// Records that the capture of [step] in [path] answers [answer] at [line], reached [through] the
  /// declarations named, and that its undo [undoActs] on it.
  const Instruction({
    required this.path,
    required this.line,
    required this.step,
    required this.answer,
    required this.through,
    required this.undoActs,
  });

  /// The repository-relative file it stands in.
  final String path;

  /// The line the refusal is folded on, counted from one.
  final int line;

  /// The class the capture and its undo stand in.
  final String step;

  /// The value the refusal makes the capture answer.
  final FoldedAnswer answer;

  /// The declarations the refusal travelled through, the capture first.
  ///
  /// A single name is a fold standing in the capture itself; more than one is a capture that hands
  /// back what another declaration answered.
  final List<String> through;

  /// Whether the undo reaches a port on this value, or null where this scan could not read the
  /// undo's own branch for it.
  ///
  /// The null is stated rather than dropped. A pair nothing could decide reads exactly like a pair
  /// that was decided and found clean, and the difference between those two is the whole reason a
  /// scan states its coverage.
  final bool? undoActs;
}

/// Every capture that answers its undo an instruction nobody measured, in the files of [scanned].
final class CapturedRefusal {
  /// Judges the Dart files of [tree] under [scanned].
  const CapturedRefusal({required this.tree, required this.scanned});

  /// The tree the files are read from.
  final SourceTree tree;

  /// The directories read, named one at a time so that widening the scan is a decision.
  final List<String> scanned;

  /// The Dart files judged, which is what every count below is stated against.
  List<String> get files => <String>[
    for (final String path in scannedFilesOf(tree, scanned))
      if (path.endsWith('.dart')) path,
  ];

  /// Every capture the judged files hold, paired with the undo it instructs.
  List<Capture> get captures => <Capture>[
    for (final String path in files) ..._judge(tree.textOf(path) ?? '', path).captures,
  ];

  /// Every value a refused reading makes a capture answer, whether it was reported or not.
  List<Instruction> get instructions => <Instruction>[
    for (final String path in files) ..._judge(tree.textOf(path) ?? '', path).instructions,
  ];

  /// Every instruction this scan could not decide, because it could not read the undo for it.
  List<Instruction> get unread => <Instruction>[
    for (final Instruction instruction in instructions)
      if (instruction.undoActs == null) instruction,
  ];

  /// Every capture that answers, on a refused reading, a value its undo acts on.
  List<Finding> get findings => <Finding>[
    for (final String path in files) ..._judge(tree.textOf(path) ?? '', path).findings,
  ];

  /// The findings of one file's [text], for a probe that plants a single file.
  static List<Finding> findingsIn(String text, String path) => _judge(text, path).findings;

  /// Everything one file's [text] answers, for a probe that states coverage as well as findings.
  static ({List<Capture> captures, List<Instruction> instructions, List<Finding> findings})
  judgementOf(String text, String path) {
    final _Judgement judged = _judge(text, path);
    return (
      captures: judged.captures,
      instructions: judged.instructions,
      findings: judged.findings,
    );
  }
}

/// What one file answered.
final class _Judgement {
  const _Judgement({required this.captures, required this.instructions, required this.findings});

  final List<Capture> captures;
  final List<Instruction> instructions;
  final List<Finding> findings;
}

/// One value a refusal makes a declaration answer, and the way it got there.
final class _Fold {
  const _Fold({required this.answer, required this.line, required this.through});

  final FoldedAnswer answer;
  final int line;
  final List<String> through;
}

/// One `if` of a body: what it asks, what it guards, and what it hands the other way.
final class _Branch {
  const _Branch({
    required this.condition,
    required this.guarded,
    required this.otherwise,
    required this.end,
    required this.chained,
  });

  final String condition;
  final CodeRegion guarded;
  final CodeRegion? otherwise;

  /// The offset just past the whole construct, where the walk goes on.
  final int end;

  /// Whether a second condition is chained onto this one, which this scan does not read.
  final bool chained;
}

/// Judges one file, over [codeOf] rather than over the text as written.
_Judgement _judge(String text, String path) {
  final String code = codeOf(text);
  final List<DartDeclaration> declarations = declarationsIn(code);

  final List<Capture> captures = <Capture>[];
  final List<Instruction> instructions = <Instruction>[];
  final List<Finding> found = <Finding>[];

  for (final DartClass step in classesIn(code)) {
    final List<DartDeclaration> own = directlyIn(step.body, declarations);
    final List<DartDeclaration> capture = <DartDeclaration>[
      for (final DartDeclaration each in own)
        if (each.name == captureName) each,
    ];
    final List<DartDeclaration> undo = <DartDeclaration>[
      for (final DartDeclaration each in own)
        if (each.name == undoName) each,
    ];
    // A class holding two of either is a class where which undo a capture instructs is a guess, and
    // this scan does not guess. It is left out of the count as well, so a tree of such classes does
    // not read as a tree that was judged and found clean.
    if (capture.length != 1 || undo.length != 1) {
      continue;
    }
    captures.add(
      Capture(
        path: path,
        line: lineAt(code, capture.single.body.start),
        step: step.name,
        undoLine: lineAt(code, undo.single.body.start),
      ),
    );

    for (final _Fold fold in _refusalAnswersOf(code, capture.single, own)) {
      final bool? acts = _undoActsOn(code, undo.single, fold.answer, own);
      instructions.add(
        Instruction(
          path: path,
          line: fold.line,
          step: step.name,
          answer: fold.answer,
          through: fold.through,
          undoActs: acts,
        ),
      );
      if (acts ?? false) {
        found.add(
          Finding(
            path,
            'the capture of ${step.name} answers ${_spelled(fold.answer)} on a reading that was '
            'refused, and the undo declared at line ${lineAt(code, undo.single.body.start)} acts on '
            'exactly that value. ${_wayThrough(fold)}. Every value a capture answers is an '
            'instruction to the undo, and there is no third value meaning nobody read this — so the '
            'undo takes something away over a machine nobody could read, while the engine is '
            'cleaning up after some other step failed. The fix is the one the closed sites use: '
            'answer the half that leaves the machine as it stands, and say out loud that it is not '
            'a measurement',
            line: fold.line,
          ),
        );
      }
    }
  }

  return _Judgement(
    captures: captures,
    instructions: instructions,
    findings: _withoutRepeats(found),
  );
}

/// How [answer] is written where a reader looks for it.
String _spelled(FoldedAnswer answer) => switch (answer) {
  FoldedAnswer.nothing => 'null',
  FoldedAnswer.no => 'false',
  FoldedAnswer.yes => 'true',
  FoldedAnswer.empty => 'an empty answer',
};

/// The way a refusal took to the capture's answer, in the words a reader follows back to the
/// command.
String _wayThrough(_Fold fold) {
  if (fold.through.length <= 1) {
    return 'The refusal is folded in the capture itself';
  }
  final List<String> back = fold.through.reversed.toList(growable: false);
  return 'The refusal is folded by ${back.first}, whose answer is handed straight back through '
      '${back.skip(1).join(', ')}';
}

/// [found] with a second finding about the same place left out.
///
/// One capture can fold the same refusal into two of the four answers, and a reader fixing the
/// place fixes both. The count is what an audit states, so a place counted twice overstates what is
/// wrong.
List<Finding> _withoutRepeats(List<Finding> found) {
  final Set<String> seen = <String>{};
  return <Finding>[
    for (final Finding finding in found)
      if (seen.add('${finding.subject}:${finding.line}')) finding,
  ];
}

/// Every value a refused reading makes [capture] answer, following what it hands back.
///
/// The walk goes only where a declaration answers ANOTHER declaration's call unchanged, which is
/// what reaches a capture written as one call. A declaration is entered once: a second way to the
/// same one is a longer way to the same answer.
List<_Fold> _refusalAnswersOf(String code, DartDeclaration capture, List<DartDeclaration> own) {
  final List<_Fold> folds = <_Fold>[];
  final Set<String> entered = <String>{};
  final List<({DartDeclaration declaration, List<String> through})> waiting =
      <({DartDeclaration declaration, List<String> through})>[
        (declaration: capture, through: <String>[capture.name]),
      ];
  while (waiting.isNotEmpty) {
    final ({DartDeclaration declaration, List<String> through}) each = waiting.removeLast();
    if (!entered.add(each.declaration.name)) {
      continue;
    }
    folds.addAll(_foldsIn(code, each.declaration, each.through));
    for (final String handed in _handedBackNames(code, each.declaration)) {
      for (final DartDeclaration next in own) {
        if (next.name == handed) {
          waiting.add((declaration: next, through: <String>[...each.through, handed]));
        }
      }
    }
  }
  return folds;
}

/// Every value a refused reading makes [declaration] itself answer.
List<_Fold> _foldsIn(String code, DartDeclaration declaration, List<String> through) {
  final Set<String> held = readingNamesIn(
    code.substring(declaration.parameters.start, declaration.body.end),
  );
  if (held.isEmpty) {
    return const <_Fold>[];
  }
  final String body = code.substring(declaration.body.start, declaration.body.end);
  final int base = declaration.body.start;
  final List<_Fold> folds = <_Fold>[];

  for (final RegExpMatch opening in ifOpening.allMatches(body)) {
    final int openBracket = opening.end - 1;
    final String whole = balancedFrom(body, openBracket);
    if (whole.length < 2) {
      continue;
    }
    final String condition = whole.substring(1, whole.length - 1);
    if (!held.any((String name) => refusesIn(condition, name))) {
      continue;
    }
    final CodeRegion? guarded = guardedAfter(code, base + openBracket + whole.length);
    if (guarded == null) {
      continue;
    }
    final FoldedAnswer? answer = answeredIn(code, guarded);
    if (answer != null) {
      folds.add(_Fold(answer: answer, line: lineAt(code, base + opening.start), through: through));
    }
  }

  for (final ({int start, int end}) answer in _answersOf(code, declaration)) {
    final String expression = code.substring(answer.start, answer.end);
    final int line = lineAt(code, answer.start);
    final int? question = topLevelAt(expression, '?');
    if (question != null) {
      final int? colon = topLevelAt(expression, ':', from: question + 1);
      if (colon == null) {
        continue;
      }
      if (!held.any((String name) => asksOk(expression.substring(0, question), name))) {
        continue;
      }
      final FoldedAnswer? folded = answeredIn(
        code,
        CodeRegion(start: answer.start + colon + 1, end: answer.end),
      );
      if (folded != null) {
        folds.add(_Fold(answer: folded, line: line, through: through));
      }
      continue;
    }
    // The whole answer IS the reading's own `ok`. There is no branch to point a reader at, and no
    // difference in the text between the tool answering "there is none" and the tool not answering
    // at all — which is what makes this the shortest way to write the defect.
    if (held.any((String name) => _isJustOk(expression, name))) {
      folds.add(_Fold(answer: FoldedAnswer.no, line: line, through: through));
    }
  }

  return folds;
}

/// Whether [expression] is nothing but [name]'s own `ok`.
bool _isJustOk(String expression, String name) =>
    RegExp('^\\s*${RegExp.escape(name)}\\s*\\.\\s*ok\\s*\$').hasMatch(expression);

/// Every declaration [declaration] hands one of its answers straight back from.
///
/// An answer is a hand-back where it is a call and NOTHING ELSE: what that declaration answers is
/// what this one answers, so a refusal folded there arrives here untouched. A declaration with
/// several answers has several hand-backs, and one of them being a bare value is what a capture
/// looks like that refuses one thing itself and asks a helper about another.
///
/// A QUALIFIED call is none of these on purpose. A call through a port or through another class is
/// not a declaration of this class, so there is nothing in this file to follow, and answering
/// otherwise would follow a name that means something else here.
List<String> _handedBackNames(String code, DartDeclaration declaration) => <String>[
  for (final ({int start, int end}) answer in _answersOf(code, declaration))
    if (_wholeCallIn(code.substring(answer.start, answer.end).trim()) case final String name) name,
];

/// The name of the call [expression] is made of, or null where it is anything but one whole call.
String? _wholeCallIn(String expression) {
  final RegExpMatch? call = _bareCall.firstMatch(expression);
  if (call == null) {
    return null;
  }
  return balancedFrom(expression, call.end - 1).length + call.end - 1 == expression.length
      ? call.group(1)
      : null;
}

/// Every expression [declaration] answers with: the one an arrow body holds, or one per `return`.
List<({int start, int end})> _answersOf(String code, DartDeclaration declaration) {
  final String body = code.substring(declaration.body.start, declaration.body.end);
  final int base = declaration.body.start;
  if (body.startsWith('=>')) {
    return <({int start, int end})>[(start: base + 2, end: declaration.body.end - 1)];
  }
  final List<({int start, int end})> answers = <({int start, int end})>[];
  for (final RegExpMatch opening in returnOpening.allMatches(body)) {
    final int? end = endOfExpression(body, opening.start);
    if (end == null) {
      continue;
    }
    answers.add((start: base + opening.end, end: base + end - 1));
  }
  return answers;
}

/// Whether [undo] reaches a port on [answer], or null where this scan could not read it.
///
/// Walked statement by statement with the value in hand. What runs BEFORE any test of the captured
/// value runs whatever the capture answered, so it carries no refusal; what a condition unrelated to
/// the value guards is stepped over whole for the same reason. The branch the value selects is the
/// one this rule is about, and it ends the walk either way: reaching a port is the taking-away, and
/// returning without reaching one is the machine being left as it stands.
bool? _undoActsOn(
  String code,
  DartDeclaration undo,
  FoldedAnswer answer,
  List<DartDeclaration> own,
) {
  final String? captured = _lastParameterName(code, undo.parameters);
  final String? given = _firstParameterName(code, undo.parameters);
  if (captured == null || given == null) {
    return null;
  }
  final String body = code.substring(undo.body.start, undo.body.end);
  if (!body.startsWith('{')) {
    // An arrow undo tests nothing, so whatever it does it does on every value alike.
    return _acts(code, undo.body, given, own);
  }

  int at = undo.body.start + 1;
  final int end = undo.body.end - 1;
  bool tested = false;
  while (at < end) {
    at = pastWhitespace(code, at);
    if (at >= end) {
      break;
    }
    final _Branch? branch = _branchAt(code, at);
    if (branch == null) {
      final int? statement = code.startsWith('{', at)
          ? endOfBlock(code, at)
          : endOfExpression(code, at);
      if (statement == null) {
        return null;
      }
      final CodeRegion region = CodeRegion(start: at, end: statement);
      if (tested) {
        if (_acts(code, region, given, own)) {
          return true;
        }
        if (_returns(code, region)) {
          return false;
        }
      }
      at = statement;
      continue;
    }
    if (!_mentions(branch.condition, captured)) {
      at = branch.end;
      continue;
    }
    if (branch.chained) {
      return null;
    }
    final bool? verdict = _conditionFor(branch.condition, captured, answer);
    if (verdict == null) {
      return null;
    }
    tested = true;
    final CodeRegion? taken = verdict ? branch.guarded : branch.otherwise;
    if (taken != null) {
      if (_acts(code, taken, given, own)) {
        return true;
      }
      if (_returns(code, taken)) {
        return false;
      }
    }
    at = branch.end;
  }
  return false;
}

/// The `if` that opens at [at], or null where something else does.
_Branch? _branchAt(String code, int at) {
  final Match? opening = ifOpening.matchAsPrefix(code, at);
  if (opening == null) {
    return null;
  }
  final int openBracket = opening.end - 1;
  final String whole = balancedFrom(code, openBracket);
  if (whole.length < 2) {
    return null;
  }
  final CodeRegion? guarded = guardedAfter(code, openBracket + whole.length);
  if (guarded == null) {
    return null;
  }
  final int after = pastWhitespace(code, guarded.end);
  if (_elseWord.matchAsPrefix(code, after) == null) {
    return _Branch(
      condition: whole.substring(1, whole.length - 1),
      guarded: guarded,
      otherwise: null,
      end: guarded.end,
      chained: false,
    );
  }
  final int otherwiseAt = pastWhitespace(code, after + 4);
  if (ifOpening.matchAsPrefix(code, otherwiseAt) != null) {
    return _Branch(
      condition: whole.substring(1, whole.length - 1),
      guarded: guarded,
      otherwise: null,
      end: guarded.end,
      chained: true,
    );
  }
  final int? otherwiseEnd = code.startsWith('{', otherwiseAt)
      ? endOfBlock(code, otherwiseAt)
      : endOfExpression(code, otherwiseAt);
  if (otherwiseEnd == null) {
    return null;
  }
  return _Branch(
    condition: whole.substring(1, whole.length - 1),
    guarded: guarded,
    otherwise: CodeRegion(start: otherwiseAt, end: otherwiseEnd),
    end: otherwiseEnd,
    chained: false,
  );
}

/// Whether [region] reaches one of [portNames] through [given], directly or through a declaration
/// of the same class whose own body reaches one.
///
/// THE CALL IS FOLLOWED RATHER THAN COUNTED, and answering on the call alone reported the very
/// treatment the finding prescribes: `fileFor`, `pathFor` — the idiom this tree writes a step's own
/// path with — reach no port, and a log line naming the file a branch is LEAVING ALONE is written
/// with one.
bool _acts(String code, CodeRegion region, String given, List<DartDeclaration> own) =>
    _reachesPort(code, region, <String>[given], own, <String>{undoName});

/// Whether [region] reaches a port through one of [receivers], or through a declaration of [own] it
/// calls that has not been [entered] yet.
///
/// A helper is read with ITS OWN parameter names in hand, because whatever it reaches a port
/// through is what that declaration binds the context to, and the name the caller used says nothing
/// about it. A QUALIFIED call is not one of these: it names a declaration of something else, and
/// following it here would follow a name that means something else in this file. A declaration is
/// entered once — its body reaches the same ports whichever call arrived at it, and a name that
/// reaches itself would otherwise never end.
bool _reachesPort(
  String code,
  CodeRegion region,
  List<String> receivers,
  List<DartDeclaration> own,
  Set<String> entered,
) {
  final String inside = code.substring(region.start, region.end);
  for (final String receiver in receivers) {
    if (_portThrough(receiver).hasMatch(inside)) {
      return true;
    }
  }
  for (final DartDeclaration declaration in own) {
    if (entered.contains(declaration.name)) {
      continue;
    }
    if (!_callOf(declaration.name).hasMatch(inside)) {
      continue;
    }
    entered.add(declaration.name);
    if (_reachesPort(
      code,
      declaration.body,
      _parameterNames(code, declaration.parameters),
      own,
      entered,
    )) {
      return true;
    }
  }
  return false;
}

/// A reach into one of [portNames] through [receiver].
RegExp _portThrough(String receiver) => RegExp(
  '(?<![\\w\$])${RegExp.escape(receiver)}\\s*\\.\\s*(?:${portNames.join('|')})(?![\\w\$])',
);

/// A call of [name] that nothing stands in front of, which is the only shape a declaration of the
/// same class is reached by.
RegExp _callOf(String name) => RegExp('(?<![\\w\$.])${RegExp.escape(name)}\\s*\\(');

/// Whether [region] hands control back rather than going on.
bool _returns(String code, CodeRegion region) =>
    _returnWord.hasMatch(code.substring(region.start, region.end));

/// Whether [condition] mentions [name] at all.
bool _mentions(String condition, String name) =>
    RegExp('(?<![\\w\$])${RegExp.escape(name)}(?![\\w\$])').hasMatch(condition);

/// Whether [condition] holds when [name] carries [answer], or null where this scan cannot say.
///
/// The two words a condition is joined with are read first, so that one half being decidable is
/// enough where it settles the whole: a disjunct that holds makes the condition hold whatever the
/// other half said.
bool? _conditionFor(String condition, String name, FoldedAnswer answer) {
  final List<String> either = _splitOn(condition, '||');
  if (either.length > 1) {
    bool allFalse = true;
    for (final String part in either) {
      final bool? each = _conditionFor(part, name, answer);
      if (each ?? false) {
        return true;
      }
      allFalse = allFalse && each == false;
    }
    return allFalse ? false : null;
  }
  final List<String> both = _splitOn(condition, '&&');
  if (both.length > 1) {
    bool allTrue = true;
    for (final String part in both) {
      final bool? each = _conditionFor(part, name, answer);
      if (each == false) {
        return false;
      }
      allTrue = allTrue && (each ?? false);
    }
    return allTrue ? true : null;
  }
  return _testFor(condition.trim(), name, answer);
}

/// Whether the single test [text] holds when [name] carries [answer], or null where this scan
/// cannot say.
///
/// A test this table does not carry is not guessed at. Guessing wrong in one direction reports a
/// step whose undo leaves the machine alone, and in the other passes over one that does not.
bool? _testFor(String text, String name, FoldedAnswer answer) {
  final String at = RegExp.escape(name);
  if (text == name) {
    return switch (answer) {
      FoldedAnswer.yes => true,
      FoldedAnswer.no => false,
      FoldedAnswer.nothing || FoldedAnswer.empty => null,
    };
  }
  if (RegExp('^!\\s*$at\$').hasMatch(text)) {
    return switch (answer) {
      FoldedAnswer.yes => false,
      FoldedAnswer.no => true,
      FoldedAnswer.nothing || FoldedAnswer.empty => null,
    };
  }
  if (RegExp('^$at\\s*==\\s*null\$').hasMatch(text)) {
    return answer == FoldedAnswer.nothing;
  }
  if (RegExp('^$at\\s*!=\\s*null\$').hasMatch(text)) {
    return answer != FoldedAnswer.nothing;
  }
  if (RegExp('^$at\\s*(==|!=)\\s*(true|false)\$').firstMatch(text) case final RegExpMatch match) {
    final bool wanted = match.group(2) == 'true';
    final bool? held = switch (answer) {
      FoldedAnswer.yes => true,
      FoldedAnswer.no => false,
      // A value that is neither of the two answers both comparisons the same way.
      FoldedAnswer.nothing => !wanted,
      FoldedAnswer.empty => null,
    };
    if (held == null) {
      return null;
    }
    return match.group(1) == '==' ? held == wanted : held != wanted;
  }
  if (RegExp('^$at\\s*\\.\\s*isEmpty\$').hasMatch(text)) {
    return answer == FoldedAnswer.empty ? true : null;
  }
  if (RegExp('^$at\\s*\\.\\s*isNotEmpty\$').hasMatch(text)) {
    return answer == FoldedAnswer.empty ? false : null;
  }
  return null;
}

/// [text] split on [token] where it stands at bracket depth zero.
List<String> _splitOn(String text, String token) {
  final List<String> parts = <String>[];
  int depth = 0;
  int from = 0;
  for (int i = 0; i < text.length; i++) {
    final String char = text[i];
    if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      depth--;
    } else if (depth == 0 && text.startsWith(token, i)) {
      parts.add(text.substring(from, i));
      i += token.length - 1;
      from = i + 1;
    }
  }
  parts.add(text.substring(from));
  return parts;
}

/// The name the first parameter of [parameters] is bound to, or null where there is none.
String? _firstParameterName(String code, CodeRegion parameters) =>
    _parameterNames(code, parameters).firstOrNull;

/// The name the last parameter of [parameters] is bound to, or null where there is none.
String? _lastParameterName(String code, CodeRegion parameters) =>
    _parameterNames(code, parameters).lastOrNull;

/// The name each parameter of [parameters] is bound to, in order.
///
/// A parameter is written type-then-name, so what is wanted is the LAST name of each entry, and a
/// default value written after it belongs to no parameter of its own.
List<String> _parameterNames(String code, CodeRegion parameters) {
  final String inside = code.substring(parameters.start, parameters.end);
  final int opening = inside.indexOf('(');
  if (opening < 0) {
    return const <String>[];
  }
  final String list = balancedFrom(inside, opening);
  if (list.length < 2) {
    return const <String>[];
  }
  return <String>[
    for (final String entry in _splitOn(list.substring(1, list.length - 1), ','))
      if (_parameterName.allMatches(entry.split('=').first).lastOrNull case final RegExpMatch name)
        name.group(1)!,
  ];
}

/// A bare call, which is the only shape a declaration of the same class is reached by.
final RegExp _bareCall = RegExp(r'^(?:await\s+)?([a-zA-Z_$][\w$]*)\s*\(');

/// The word a second half of a condition is written after.
final RegExp _elseWord = RegExp(r'else(?![\w$])');

/// A `return`, with or without a value.
final RegExp _returnWord = RegExp(r'(?<![\w$])return(?![\w$])');

/// A name a parameter entry may bind.
final RegExp _parameterName = RegExp(r'([a-zA-Z_$][\w$]*)');
