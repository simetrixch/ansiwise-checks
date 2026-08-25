/// The suite that drives [RefusedReading] over one tree, with the counter-probes beside it.
library;

import 'package:test/test.dart';

import '../finding.dart';
import '../refused_reading.dart';
import '../source_tree.dart';

/// Runs the refused-reading audit over [tree], or over the repository this suite sits in.
///
/// [scannedPaths] are the directories read, named one at a time by the caller rather than derived,
/// so widening the scan is a decision somebody makes rather than a silent change.
///
/// WHAT IT STATES: how many Dart files were read, how many readings of the machine they hold, how
/// many branches a refused reading reaches, and how many `CheckResult.satisfied` answers the rule is
/// about. The last is the population: a tree that answers satisfied nowhere is a tree this scan
/// decided nothing over, and on the screen that reads exactly like a tree it found clean.
///
/// **NONE OF THOSE COUNTS HAS A FLOOR, and no test asserts one.** A package of value objects makes
/// no reading; a package whose steps all block rather than answer satisfied writes none of the
/// second; and either is a clean tree, not a broken scan. A check that went red on such a tree would
/// state a reason that is not true of it, which is the one thing a check may never do. What holds
/// the scan honest instead is the test below it — every satisfied answer stands INSIDE a declaration
/// this scan found — and the counter-probes on planted text, which prove the shapes are still
/// recognised whatever the tree in front of them happens to hold.
///
/// **Why that one test is the guard that matters.** The whole chain is followed inside declaration
/// bodies. If the reader that finds a body stops recognising one — a shape of declaration nobody
/// thought of, a brace counted in the wrong place — the chain is followed nowhere, every tree comes
/// back clean, and nothing on the screen changes but a number. So the answers this scan judged are
/// held against the answers the tree actually writes, and a gap between them is reported as the
/// coverage loss it is rather than as silence.
void auditRefusedReading({required List<String> scannedPaths, SourceTree? tree}) {
  final SourceTree judged = tree ?? SourceTree.on(repositoryRoot());
  final RefusedReading scan = RefusedReading(tree: judged, scanned: scannedPaths);
  final List<Reading> readings = scan.readings;
  final List<Refusal> refusals = scan.refusals;
  final List<SatisfiedAnswer> answers = scan.answers;
  final List<Finding> findings = scan.findings;
  final String where = scannedPaths.join(', ');

  test('${scan.files.length} Dart file(s) under $where were read', () {
    expect(scan.files, isNotEmpty, reason: 'no Dart file of $where is in this tree');
  });

  test('${readings.length} reading(s) of the machine, ${refusals.length} branch(es) a refused '
      'reading reaches, and ${answers.length} satisfied answer(s) were found to judge', () {
    expect(
      readings.length + answers.length,
      greaterThanOrEqualTo(0),
      reason: 'the three numbers above are the coverage this scan is stating, not a threshold',
    );
  });

  test('every satisfied answer stands inside a declaration this scan found', () {
    expect(
      <String>[
        for (final SatisfiedAnswer answer in answers)
          if (!answer.insideDeclaration) '${answer.path}:${answer.line}',
      ],
      isEmpty,
      reason:
          'the chain a refusal travels is followed inside declaration bodies, so an answer standing '
          'in none of them is an answer nothing judged — and a tree of them comes back clean while '
          'the scan is looking nowhere',
    );
  });

  test('no satisfied answer stands on a reading that was refused', () {
    expect(findings, isEmpty, reason: findings.join('; '));
  });

  group('counter-probe', () {
    // THE MEASUREMENT THAT COST EIGHT SATISFIED ROWS. Two hops from the refused command to the
    // claim, which is why the chain is followed at all: a scan reading only the branch the refusal
    // opens is green on every one of the three declarations below.
    test('THE PLANTED DEFECT: a refused command carried two hops into a satisfied is reported', () {
      const String planted = '''
final class MeasurePublicNic extends ObservingStep {
  static Future<List<_DefaultRoute>> _defaultRoutes(StepContext context) async {
    final CommandResult routes = await context.shell.run(
      const Command.observing('ip', arguments: <String>['-4', 'route', 'show', 'default']),
    );
    if (!routes.ok) {
      return const <_DefaultRoute>[];
    }
    return <_DefaultRoute>[
      for (final String line in routes.stdout.split('|'))
        if (_DefaultRoute.read(line) case final _DefaultRoute route) route,
    ];
  }

  static Future<PublicNic?> measure(StepContext context) async {
    final List<_DefaultRoute> routes = await _defaultRoutes(context);
    if (routes.isEmpty) {
      return null;
    }
    return PublicNic(device: routes.first.device);
  }

  @override
  Future<CheckResult> check(StepContext context) async {
    final PublicNic? nic = await measure(context);
    if (nic == null) {
      return const CheckResult.satisfied(
        'the default route already leaves by the interface carrying the public address',
      );
    }
    return CheckResult.satisfied('steered out the other one');
  }
}
''';

      final List<Finding> found = RefusedReading.findingsIn(planted, 'lib/measure_public_nic.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 27);
      expect(found.single.what, contains('_defaultRoutes'));
      expect(found.single.what, contains('measure'));
      expect(
        found.single.what,
        contains('line 6'),
        reason:
            'the finding is what an operator opens, and the branch alone does not say which '
            'command was refused three declarations further up',
      );
    });

    test('THE SAME SHAPE RESTORED: the refusal throws, so nothing travels and the tree is '
        'green', () {
      // The fix the sweep made. The engine wraps every check in one catch and turns what is thrown
      // into a refusal naming the tool's own words, so throwing IS how a measurement says it was
      // not taken — and it needs no branch in any of the eight steps that read the answer.
      const String planted = '''
final class MeasurePublicNic extends ObservingStep {
  static Future<List<_DefaultRoute>> _defaultRoutes(StepContext context) async {
    final CommandResult routes = await context.shell.run(
      const Command.observing('ip', arguments: <String>['-4', 'route', 'show', 'default']),
    );
    if (!routes.ok) {
      throw CommandFailed(
        argv: _showDefaultRoutes,
        exitCode: routes.exitCode,
        stdout: '',
        stderr: routes.stderr,
      );
    }
    return <_DefaultRoute>[
      for (final String line in routes.stdout.split('|'))
        if (_DefaultRoute.read(line) case final _DefaultRoute route) route,
    ];
  }

  static Future<PublicNic?> measure(StepContext context) async {
    final List<_DefaultRoute> routes = await _defaultRoutes(context);
    if (routes.isEmpty) {
      return null;
    }
    return PublicNic(device: routes.first.device);
  }

  @override
  Future<CheckResult> check(StepContext context) async {
    final PublicNic? nic = await measure(context);
    if (nic == null) {
      return const CheckResult.satisfied(
        'the default route already leaves by the interface carrying the public address',
      );
    }
    return CheckResult.satisfied('steered out the other one');
  }
}
''';

      expect(RefusedReading.findingsIn(planted, 'lib/measure_public_nic.dart'), isEmpty);
    });

    test('a refusal answering satisfied in the same breath is reported', () {
      // The shortest way to write the same defect, and the one a reader recognises at once. It is
      // planted beside the two-hop shape rather than instead of it, because a scan that only
      // followed chains would be blind to the obvious spelling.
      const String planted = '''
final class AlignBackend extends ReversibleStep<String> {
  @override
  Future<CheckResult> check(StepContext context) async {
    final CommandResult read = await context.shell.run(
      Command.observing('readlink', arguments: <String>['-f', link]),
    );
    if (!read.ok) {
      return const CheckResult.satisfied('nothing here says which backend to align to');
    }
    return const CheckResult.ready();
  }
}
''';

      final List<Finding> found = RefusedReading.findingsIn(planted, 'lib/align_backend.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 8);
    });

    // THE INNOCENT NEIGHBOURS, drawn from the sweep's own taxonomy rather than invented. Without
    // them a scan that reported every satisfied answer in the tree would pass every probe above,
    // and a clean run would mean nothing.
    test('THE HOUSE TREATMENT: a value naming the refusal ends the chain', () {
      // enable_service, and the shape twelve places in the tree already carry. `_Unit.unreadable`
      // is not a bare value, so nothing travels out of the branch — and the satisfied written
      // below it stands on a reading that WAS taken.
      const String planted = '''
final class EnableService extends ReversibleStep<bool> {
  @override
  Future<CheckResult> check(StepContext context) async {
    final _Unit state = await _read(context);
    if (state.refusal case final String refusal) {
      return CheckResult.blocked(refusal);
    }
    if (state.said['UnitFileState'] == 'enabled') {
      return const CheckResult.satisfied('the unit is enabled');
    }
    return const CheckResult.ready();
  }

  Future<_Unit> _read(StepContext context) async {
    final CommandResult shown = await context.shell.run(
      Command.observing('systemctl', arguments: <String>['show', unitName]),
    );
    if (!shown.ok) {
      return _Unit.unreadable('systemctl could not be asked about the unit');
    }
    return _Unit.of(_fields(shown.stdout));
  }
}
''';

      expect(RefusedReading.findingsIn(planted, 'lib/enable_service.dart'), isEmpty);
    });

    test('THE EXIT CODE IS THE ANSWER: a folded test -L that reaches no satisfied is green', () {
      // link_storage_path. `test -L` exits non-zero for a path that is not a link, so the fold IS
      // the answer — and the two satisfied answers of this check stand on the branch where a link
      // was found, never on the null the refusal takes. A scan judging the FOLD rather than the
      // claim would report this place, and its only fix would be to stop using the exit code of a
      // command whose exit code is what it answers with.
      const String planted = '''
final class LinkStoragePath extends IrreversibleStep {
  @override
  Future<CheckResult> check(StepContext context) async {
    final String? target = await _linkTarget(context);
    if (target == context.answers.text('storage_subdirectory')) {
      return CheckResult.satisfied('the link points at the storage subdirectory');
    }
    if (target != null && !force) {
      return CheckResult.satisfied('the link points elsewhere and was left alone');
    }
    return const CheckResult.ready();
  }

  Future<String?> _linkTarget(StepContext context) async {
    final CommandResult isLink = await context.shell.run(
      Command.observing('test', arguments: <String>['-L', linkPath]),
    );
    if (!isLink.ok) {
      return null;
    }
    final CommandResult target = await context.shell.run(
      Command.observing('readlink', arguments: <String>['-f', linkPath]),
    );
    return target.ok && target.trimmed.isNotEmpty ? target.trimmed : null;
  }
}
''';

      expect(RefusedReading.findingsIn(planted, 'lib/link_storage_path.dart'), isEmpty);
    });

    test("NOT THIS SHAPE AT ALL: the ?? '' family is argument resolution", () {
      // The sweep read this family in two packages and found it is a value object whose refusal
      // travels separately in `.refusal`, answered before the value is read at all. A scan matching
      // `?? ''` would report every one of them, which is the noise that gets a check switched off.
      const String planted = r'''
final class RemoveVaultKvEntry extends IrreversibleStep {
  @override
  Future<CheckResult> check(StepContext context) async {
    final VaultProfile vault = await vaultProfileFrom(context, repository, layout: layout);
    if (vault.refusal case final String refusal) {
      return CheckResult.blocked(refusal);
    }
    final HttpAnswer answer = await context.http.send(
      vaultRead(vault.url ?? '', metadataPath, token: token.value ?? ''),
    );
    if (isAbsent(answer)) {
      return CheckResult.satisfied('the store holds nothing at $metadataPath');
    }
    if (!answer.ok) {
      return CheckResult.blocked('reading it answered neither what it holds nor that it holds none');
    }
    return const CheckResult.ready();
  }
}
''';

      expect(RefusedReading.findingsIn(planted, 'lib/remove_vault_kv_entry.dart'), isEmpty);
    });

    test('FAIL-SAFE: a refusal that leads to MORE work is not a false done', () {
      // apply_netplan, left standing by the sweep with the cost named: a refused `ip rule show`
      // means "the rule is missing", which makes the step Ready and the work happen. That costs one
      // unnecessary network apply and never a green row over a machine nobody read. This scan holds
      // the claim rather than the fold, so it is silent here on purpose — and the day somebody
      // rewrites the caller to answer satisfied instead, the same planted text goes red.
      const String planted = '''
final class ApplyNetplan extends IrreversibleStep {
  @override
  Future<CheckResult> check(StepContext context) async {
    if (!await _hasRule(context, nic)) {
      return const CheckResult.ready();
    }
    return const CheckResult.satisfied('the rule is installed');
  }

  Future<bool> _hasRule(StepContext context, PublicNic nic) async {
    final CommandResult rules = await context.shell.run(
      const Command.observing('ip', arguments: <String>['-4', 'rule', 'show']),
    );
    if (!rules.ok) {
      return false;
    }
    return rules.stdout.split('|').any((String line) => line.contains(nic.address));
  }
}
''';

      expect(RefusedReading.findingsIn(planted, 'lib/apply_netplan.dart'), isEmpty);
    });

    test('and the same fail-safe caller answering satisfied instead IS reported', () {
      // The other half of the probe above, and what makes its silence mean something. Nothing about
      // the fold changed; what changed is where it lands, which is the whole rule in one pair.
      const String planted = '''
final class ApplyNetplan extends IrreversibleStep {
  @override
  Future<CheckResult> check(StepContext context) async {
    if (!await _hasRule(context, nic)) {
      return const CheckResult.satisfied('this machine has no rule to install');
    }
    return const CheckResult.ready();
  }

  Future<bool> _hasRule(StepContext context, PublicNic nic) async {
    final CommandResult rules = await context.shell.run(
      const Command.observing('ip', arguments: <String>['-4', 'rule', 'show']),
    );
    if (!rules.ok) {
      return false;
    }
    return rules.stdout.split('|').any((String line) => line.contains(nic.address));
  }
}
''';

      final List<Finding> found = RefusedReading.findingsIn(planted, 'lib/apply_netplan.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 5);
      expect(found.single.what, contains('_hasRule'));
    });

    test('a reading a helper is HANDED is one it holds, so its refusal is judged there', () {
      // The half that read nothing for as long as the scan wanted an assignment: the answer arrives
      // as a parameter, which is how a helper that decides what an answer SAYS takes it. One whole
      // package reaches the machine only through such a helper.
      const String planted = '''
ApiReading resultOf(HttpAnswer answer, {required String what}) {
  if (!answer.ok) {
    return const CheckResult.satisfied('the zone holds nothing');
  }
  return ApiHeld(answer.body);
}
''';

      final List<Finding> found = RefusedReading.findingsIn(planted, 'lib/api_answer.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 3);
    });

    test('THE INNOCENT NEIGHBOUR: the same helper answering a refusal is green', () {
      const String planted = '''
ApiReading resultOf(HttpAnswer answer, {required String what}) {
  if (!answer.ok) {
    return ApiRefused('\$what answered neither what stands there nor that nothing does');
  }
  return ApiHeld(answer.body);
}
''';

      expect(RefusedReading.findingsIn(planted, 'lib/api_answer.dart'), isEmpty);
    });

    test('a ternary is the same fold written as one expression, and is followed', () {
      // `answer.ok && answer.trimmed.isNotEmpty ? answer.trimmed : null` is how the shortest of
      // these are written. A scan reading only `if` statements would be blind to every one of them.
      const String planted = '''
final class GitMergeRef extends ReversibleStep<String?> {
  @override
  Future<CheckResult> check(StepContext context) async {
    final String? head = await _head(context);
    if (head == null) {
      return const CheckResult.satisfied('there is nothing to merge into');
    }
    return const CheckResult.ready();
  }

  Future<String?> _head(StepContext context) async {
    final CommandResult head = await context.shell.run(
      Command.observing('git', arguments: <String>['rev-parse', 'HEAD']),
    );
    return head.ok && head.trimmed.isNotEmpty ? head.trimmed : null;
  }
}
''';

      final List<Finding> found = RefusedReading.findingsIn(planted, 'lib/git_merge_ref.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 6);
    });

    test('an empty answer carried on is told apart by isEmpty, which is how a listing folds', () {
      const String planted = '''
final class HelmRelease extends ReversibleStep<String?> {
  @override
  Future<CheckResult> check(StepContext context) async {
    final List<String> releases = await _releases(context);
    if (releases.isEmpty) {
      return const CheckResult.satisfied('this namespace holds no release of ours');
    }
    return const CheckResult.ready();
  }

  Future<List<String>> _releases(StepContext context) async {
    final CommandResult listed = await context.shell.run(
      helm.observing(<String>['list', '--namespace', namespace, '-o', 'json']),
    );
    if (!listed.ok) {
      return const <String>[];
    }
    return _namesIn(listed.trimmed);
  }
}
''';

      final List<Finding> found = RefusedReading.findingsIn(planted, 'lib/helm_release.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 6);
    });

    // A REGION IS FOUND BY COUNTING BRACES, so it is counted over `codeOf` and never over the file
    // as written. Each of the two below reports the wrong thing the moment that stops being true,
    // and they fail in opposite directions.
    test('a brace inside a comment does not carry the branch onto the answer below it', () {
      // The loud one: counted over the raw text, the brace in the comment runs the refusal's branch
      // past its own closing brace and swallows the satisfied written after it — so a step whose
      // refusal blocks is reported, and the only fix a reader can see is to delete the comment.
      const String planted = '''
final class RequireFreeDisk extends ObservingStep {
  @override
  Future<CheckResult> check(StepContext context) async {
    final CommandResult measured = await context.shell.run(
      Command.observing('df', arguments: <String>['-B1', '--output=avail', path]),
    );
    if (!measured.ok) {
      // The old spelling of this branch read `if (measured.ok) {` and answered the other way.
      return CheckResult.blocked('df could not measure the path');
    }
    return const CheckResult.satisfied('there is room enough');
  }
}
''';

      expect(RefusedReading.findingsIn(planted, 'lib/require_free_disk.dart'), isEmpty);
    });

    test('a brace inside a string does not end the branch before the answer it reaches', () {
      // The silent one, and the worse of the two: counted over the raw text the brace inside the
      // warning ends the branch early, so the satisfied that really does stand on the refusal is
      // never judged — while the file goes on being counted among the files this scan judged.
      const String planted = r'''
final class RequireFreeDisk extends ObservingStep {
  @override
  Future<CheckResult> check(StepContext context) async {
    final CommandResult measured = await context.shell.run(
      Command.observing('df', arguments: <String>['-B1', '--output=avail', path]),
    );
    if (!measured.ok) {
      context.log.warn('df wrote nothing but a brace }');
      return const CheckResult.satisfied('there is room enough');
    }
    return const CheckResult.ready();
  }
}
''';

      final List<Finding> found = RefusedReading.findingsIn(planted, 'lib/require_free_disk.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 9);
    });

    test('a branch that never closes claims no region, so nothing below it is judged', () {
      // Where a body or a branch does not close, this scan does not know where it stops. A region
      // running to the end of the file would put every answer written below it on a refusal that
      // ended somewhere above, so nothing is claimed and the file is judged by what remains.
      const String planted = '''
final class Broken extends ObservingStep {
  Future<CheckResult> check(StepContext context) async {
    final CommandResult measured = await context.shell.run(command);
    if (!measured.ok) {
      return const CheckResult.satisfied('nothing to do');
''';

      expect(RefusedReading.findingsIn(planted, 'lib/broken.dart'), isEmpty);
    });

    test('a scan over a tree reads every file of it and states what it held', () {
      // The whole-tree entry point, which is what an audit runs. The per-file entry point above
      // cannot show that the file list, the readings and the answers are read off the same tree.
      final SourceTree planted = SourceTree.planted(<String, String?>{
        'pubspec.yaml': 'name: planted_package\n',
        'lib/measure.dart': '''
final class Measure extends ObservingStep {
  @override
  Future<CheckResult> check(StepContext context) async {
    final CommandResult read = await context.shell.run(command);
    if (!read.ok) {
      return const CheckResult.satisfied('nothing to do');
    }
    return const CheckResult.ready();
  }
}
''',
        // Not text. A byte scan over an image reports matches nobody can act on, so a file holding
        // a zero byte is counted as present and left unread.
        'lib/logo.png': null,
      });

      final RefusedReading scan = RefusedReading(tree: planted, scanned: const <String>['lib']);

      expect(scan.files, <String>['lib/measure.dart']);
      expect(scan.readings, hasLength(1));
      expect(scan.answers, hasLength(1));
      expect(scan.answers.single.insideDeclaration, isTrue);
      expect(scan.findings, hasLength(1));
      expect(scan.findings.single.subject, 'lib/measure.dart');
    });

    test('an answer standing in no declaration is counted as one this scan did not judge', () {
      // What the coverage test above goes red on. A satisfied answer at the top level of a file
      // sits inside no body, so the chain is followed nowhere near it — and saying so is the
      // difference between a scan that found nothing and a scan that looked nowhere.
      final SourceTree planted = SourceTree.planted(<String, String?>{
        'pubspec.yaml': 'name: planted_package\n',
        'lib/constant.dart': "const CheckResult always = CheckResult.satisfied('always');\n",
      });

      final RefusedReading scan = RefusedReading(tree: planted, scanned: const <String>['lib']);

      expect(scan.answers, hasLength(1));
      expect(scan.answers.single.insideDeclaration, isFalse);
    });
  });
}
