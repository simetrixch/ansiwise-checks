/// The suite that drives [CapturedRefusal] over one tree, with the counter-probes beside it.
library;

import 'package:test/test.dart';

import '../captured_refusal.dart';
import '../finding.dart';
import '../source_tree.dart';

/// Runs the captured-refusal audit over [tree], or over the repository this suite sits in.
///
/// [scannedPaths] are the directories read, named one at a time by the caller rather than derived,
/// so widening the scan is a decision somebody makes rather than a silent change.
///
/// WHAT IT STATES: how many Dart files were read, how many captures they hold paired with the undo
/// each one instructs, how many values a refused reading makes one of those captures answer, and how
/// many of those values this scan could not decide the undo for. The second is the population: a
/// tree holding no capture is a tree this scan decided nothing over, and on the screen that reads
/// exactly like a tree it found clean.
///
/// **NONE OF THOSE COUNTS HAS A FLOOR, and no test asserts one.** A package of value objects holds
/// no capture; a package whose captures all answer a record that names its own refusal folds
/// nothing; and either is a clean tree, not a broken scan. A check that went red on such a tree
/// would state a reason that is not true of it, which is the one thing a check may never do. What
/// holds the scan honest instead is the test below it — every value it found was decided, or is
/// counted as one it could not decide — and the counter-probes on planted text, which prove the
/// shapes are still recognised whatever the tree in front of them happens to hold.
///
/// **Why the undecided count is a test of its own.** The whole rule turns on reading the undo. If
/// the reader that finds a body or the table that decides a condition stops recognising a shape, the
/// answer becomes "could not decide" rather than "found nothing" — and without a number for it, a
/// tree where nothing could be decided comes back exactly as green as a tree where everything was.
void auditCapturedRefusal({required List<String> scannedPaths, SourceTree? tree}) {
  final SourceTree judged = tree ?? SourceTree.on(repositoryRoot());
  final CapturedRefusal scan = CapturedRefusal(tree: judged, scanned: scannedPaths);
  final List<Capture> captures = scan.captures;
  final List<Instruction> instructions = scan.instructions;
  final List<Instruction> unread = scan.unread;
  final List<Finding> findings = scan.findings;
  final String where = scannedPaths.join(', ');

  test('${scan.files.length} Dart file(s) under $where were read', () {
    expect(scan.files, isNotEmpty, reason: 'no Dart file of $where is in this tree');
  });

  test('${captures.length} capture(s) with the undo each instructs, and '
      '${instructions.length} value(s) a refused reading makes one of them answer, were found to '
      'judge', () {
    expect(
      captures.length + instructions.length,
      greaterThanOrEqualTo(0),
      reason: 'the two numbers above are the coverage this scan is stating, not a threshold',
    );
  });

  // NAMED ONE AT A TIME AND NEVER COUNTED, because a value nothing could decide reads on the screen
  // exactly like a value that was decided and found clean. Like the two numbers above it this
  // asserts no threshold — there is none to assert, and a test that went red on the first
  // undecidable undo would be red about the scan rather than about the tree.
  test('${unread.length} of those value(s) could not be decided, because the undo could not be '
      'read for them${unread.isEmpty ? '' : ': ${_named(unread)}'}', () {
    expect(
      unread.length,
      greaterThanOrEqualTo(0),
      reason: 'the names above are what this scan decided nothing about, not a threshold',
    );
  });

  test('no capture answers, on a refused reading, a value its undo acts on', () {
    expect(findings, isEmpty, reason: findings.join('; '));
  });

  group('counter-probe', () {
    // THE SHAPE THAT COST A MEMBERSHIP, in the form it stood in before the sweep closed it. Two
    // declarations from the refused command to the instruction, which is why the chain is followed
    // at all: a scan reading only the capture's own body is green on this.
    test('THE PLANTED DEFECT: a refused reading carried into the half the undo deletes on is '
        'reported', () {
      const String planted = '''
final class AddUserToGroup extends ReversibleStep<bool> {
  @override
  Future<bool> capture(StepContext context) async {
    final String? gid = await _gidOf(context);
    if (gid == null) {
      return false;
    }
    return _isMember(context, gid);
  }

  Future<bool> _isMember(StepContext context, String gid) async {
    final CommandResult carried = await context.shell.run(
      Command.observing('id', arguments: <String>['-G', userIn(context)]),
    );
    if (!carried.ok) {
      return false;
    }
    return carried.stdout.split(RegExp(r'\\s+')).contains(gid);
  }

  @override
  Future<void> undo(StepContext context, bool captured) async {
    if (captured) {
      return;
    }
    await context.shell.run(
      Command.detailed(
        'gpasswd',
        arguments: <String>['--delete', userIn(context), group],
        elevated: true,
      ),
    );
  }
}
''';

      final List<Finding> found = CapturedRefusal.findingsIn(planted, 'lib/add_user_to_group.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 15);
      expect(found.single.what, contains('_isMember'));
      expect(found.single.what, contains('AddUserToGroup'));
      expect(
        found.single.what,
        contains('false'),
        reason:
            'the finding is what an operator opens, and the branch alone does not say which of the '
            'two halves the undo was handed',
      );
    });

    test('THE SAME SHAPE RESTORED: the refusal answers the half that leaves the machine alone, so '
        'the tree is green', () {
      // The fix the sweep made, word for word in its shape: a helper that says out loud that this
      // is not a measurement and answers the other half. A call is not a bare value, so nothing
      // travels out of the branch, and the undo is handed the half that returns.
      const String planted = '''
final class AddUserToGroup extends ReversibleStep<bool> {
  @override
  Future<bool> capture(StepContext context) async {
    final String? gid = await _gidOf(context);
    if (gid == null) {
      return _leaveAlone(context, 'no group on this machine answered to "\$group"');
    }
    final bool? member = await _isMember(context, gid);
    if (member == null) {
      return _leaveAlone(context, 'the groups of \${userIn(context)} could not be read');
    }
    return member;
  }

  bool _leaveAlone(StepContext context, String refusal) {
    context.log.warn(
      'whether \${userIn(context)} was already in \$group could not be read, so an undo will leave '
      'the membership alone rather than take away one this run may not have given: \$refusal',
    );
    return true;
  }

  Future<bool?> _isMember(StepContext context, String gid) async {
    final CommandResult carried = await context.shell.run(
      Command.observing('id', arguments: <String>['-G', userIn(context)]),
    );
    if (!carried.ok) {
      return null;
    }
    return carried.stdout.split(RegExp(r'\\s+')).contains(gid);
  }

  @override
  Future<void> undo(StepContext context, bool captured) async {
    if (captured) {
      return;
    }
    await context.shell.run(
      Command.detailed(
        'gpasswd',
        arguments: <String>['--delete', userIn(context), group],
        elevated: true,
      ),
    );
  }
}
''';

      expect(CapturedRefusal.findingsIn(planted, 'lib/add_user_to_group.dart'), isEmpty);
    });

    test('an answer that IS the reading\'s own ok is the shortest way to write it, and is '
        'reported', () {
      // The two sites the ticket recorded and the third nobody had named. There is no branch here
      // at all: a get of a named object exits non-zero for a cluster that does not hold it and for
      // a cluster that could not be asked, and the answer is that exit code.
      const String planted = '''
final class KubernetesObjectReversible extends ReversibleStep<bool> {
  @override
  Future<bool> capture(StepContext context) async {
    final CommandResult found = await context.shell.run(
      kubectl.observing(<String>['get', '--filename', path, '-o', 'name']),
    );
    return found.ok;
  }

  @override
  Future<void> undo(StepContext context, bool captured) async {
    if (captured) {
      return;
    }
    await context.shell.run(
      kubectl.command(<String>['delete', '--filename', path, '--ignore-not-found']),
    );
  }
}
''';

      final List<Finding> found = CapturedRefusal.findingsIn(planted, 'lib/object.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 7);
    });

    test('THE HOUSE TREATMENT: asking the LIST as well tells the two apart, and is green', () {
      // What closed the Secret site. A list of the kind exits ZERO for a namespace holding none, so
      // its exit code really is an answer — and the branch where it does not answer says so and
      // hands back the half that leaves the object standing.
      const String planted = '''
final class KubernetesSecretFromVault extends ReversibleStep<bool> {
  @override
  Future<bool> capture(StepContext context) => _isThere(context);

  @override
  Future<void> undo(StepContext context, bool captured) async {
    if (captured) {
      return;
    }
    await context.shell.run(
      kubectl.command(<String>['delete', 'secret', name, '--namespace', namespace]),
    );
  }

  Future<bool> _isThere(StepContext context) async {
    final CommandResult found = await context.shell.run(
      kubectl.observing(<String>['get', 'secret', name, '--namespace', namespace, '-o', 'name']),
    );
    if (found.ok) {
      return true;
    }
    final CommandResult listed = await context.shell.run(
      kubectl.observing(<String>['get', 'secret', '--namespace', namespace, '-o', 'name']),
    );
    if (listed.ok) {
      return false;
    }
    context.log.warn(
      'whether \$namespace already held a Secret called \$name could not be read, so an undo will '
      'leave it alone rather than delete one this run may not have created',
    );
    return true;
  }
}
''';

      expect(CapturedRefusal.findingsIn(planted, 'lib/secret.dart'), isEmpty);
    });

    test('THE HOUSE TREATMENT: the same fold answered the other way round is green, and the undo '
        'is what makes it so', () {
      // The tag site. The fold is a bare `true` and the scan sees it, which is the point: what
      // makes this green is not the capture on its own but the half the undo returns on. Nothing
      // about the capture changed between this probe and the one below it.
      const String planted = '''
final class GitTag extends ReversibleStep<bool> {
  @override
  Future<bool> capture(StepContext context) async {
    final CommandResult remote = await context.shell.run(
      Command.observing('git', arguments: <String>['ls-remote', '--tags', name]),
    );
    if (!remote.ok) {
      context.log.warn('whether the remote carried \$tag could not be read');
      return true;
    }
    return remote.trimmed.isNotEmpty;
  }

  @override
  Future<void> undo(StepContext context, bool captured) async {
    if (captured) {
      return;
    }
    await context.shell.run(
      Command.detailed('git', arguments: <String>['push', '--delete', name, tag]),
    );
  }
}
''';

      final ({List<Capture> captures, List<Instruction> instructions, List<Finding> findings})
      judged = CapturedRefusal.judgementOf(planted, 'lib/git_tag.dart');

      expect(judged.findings, isEmpty);
      expect(
        judged.instructions,
        hasLength(1),
        reason: 'the fold is seen; what makes it harmless is the half the undo returns on',
      );
      expect(judged.instructions.single.undoActs, isFalse);
    });

    test('and the same capture answering the OTHER half IS reported', () {
      // The other half of the probe above, and what makes its silence mean something. Nothing about
      // the undo changed; what changed is which half the refusal is answered as, which is the whole
      // rule in one pair.
      const String planted = '''
final class GitTag extends ReversibleStep<bool> {
  @override
  Future<bool> capture(StepContext context) async {
    final CommandResult remote = await context.shell.run(
      Command.observing('git', arguments: <String>['ls-remote', '--tags', name]),
    );
    if (!remote.ok) {
      return false;
    }
    return remote.trimmed.isNotEmpty;
  }

  @override
  Future<void> undo(StepContext context, bool captured) async {
    if (captured) {
      return;
    }
    await context.shell.run(
      Command.detailed('git', arguments: <String>['push', '--delete', name, tag]),
    );
  }
}
''';

      final List<Finding> found = CapturedRefusal.findingsIn(planted, 'lib/git_tag.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 7);
    });

    // THE INNOCENT NEIGHBOURS THAT DECIDE THE COUNT. Without them a scan reporting every fold in
    // every capture would pass every probe above, and would report a third of the tree.
    test('A FOLD THE UNDO RETURNS ON IS THE HOUSE TREATMENT, and is green', () {
      // helm_repository, which says at length why it leaves the registration standing. The capture
      // folds a refused listing into null; the undo writes a line for the record and returns. A
      // branch that reaches no port changes nothing, whatever else it writes.
      const String planted = '''
final class HelmRepository extends ReversibleStep<String?> {
  @override
  Future<String?> capture(StepContext context) => _registeredUrl(context);

  @override
  Future<void> undo(StepContext context, String? captured) async {
    if (captured == null) {
      context.log.info(
        'the registration of "\$name" stands: helm held no such name before this run',
      );
      return;
    }
    await context.shell.run(
      helm.command(<String>['repo', 'add', name, captured, '--force-update']),
    );
  }

  Future<String?> _registeredUrl(StepContext context) async {
    final CommandResult listed = await context.shell.run(
      helm.observing(<String>['repo', 'list', '-o', 'json']),
    );
    if (!listed.ok || listed.trimmed.isEmpty) {
      return null;
    }
    return _urlIn(listed.trimmed);
  }
}
''';

      final ({List<Capture> captures, List<Instruction> instructions, List<Finding> findings})
      judged = CapturedRefusal.judgementOf(planted, 'lib/helm_repository.dart');

      expect(judged.findings, isEmpty);
      expect(judged.instructions, hasLength(1));
      expect(judged.instructions.single.undoActs, isFalse);
    });

    // A BRANCH REACHES A PORT THROUGH THE CONTEXT OR THROUGH A DECLARATION OF THE SAME CLASS, and
    // the pair below is what holds the second half honest in both directions. Counting the call
    // reported the treatment; dropping it passes over an undo that removes the object one hop away.
    test('A BRANCH THAT NAMES THE FILE IT LEAVES ALONE REACHES NO PORT, and is green', () {
      // file_from_vault's own idiom, on a reading whose `ok` this rule can see. The capture answers
      // the half that leaves the file where it is and says out loud that it is not a measurement;
      // the undo writes down WHICH file it is leaving and returns. `fileFor` is a declaration of
      // the same class and reads nothing but this step's own path, so the branch touches no port —
      // and reporting it would put a finding on the code the finding tells a reader to write.
      const String planted = '''
final class FileFromVault extends ReversibleStep<bool> {
  @override
  Future<bool> capture(StepContext context) async {
    final CommandResult found = await context.shell.run(
      Command.observing('vault', arguments: <String>['kv', 'get', entry]),
    );
    if (!found.ok) {
      context.log.warn(
        'whether \${fileFor(context)} was already there could not be read, so an undo will leave '
        'it alone rather than delete a file this run may not have written',
      );
      return true;
    }
    return found.stdout.isNotEmpty;
  }

  @override
  Future<void> undo(StepContext context, bool captured) async {
    if (captured) {
      context.log.info('leaving \${fileFor(context)} alone: this run did not write it');
      return;
    }
    await context.files.delete(fileFor(context), elevated: elevated);
  }

  String fileFor(StepContext context) => layout.runAnswerFilled(context, filePath);
}
''';

      final ({List<Capture> captures, List<Instruction> instructions, List<Finding> findings})
      judged = CapturedRefusal.judgementOf(planted, 'lib/file_from_vault.dart');

      expect(judged.findings, isEmpty);
      expect(judged.instructions, hasLength(1));
      expect(judged.instructions.single.undoActs, isFalse);
    });

    test('THE PLANTED DEFECT: a port the branch reaches through a helper of the same class is '
        'still the undo acting, and is reported', () {
      // What the following of the call is FOR. The delete stands one hop away, in a declaration the
      // branch calls, and a rule reading the branch's own text alone is green on a step that
      // removes the namespace anyway. This is the probe the clause above has to keep passing: drop
      // the following and this text stops being reported.
      const String planted = '''
final class KubernetesNamespace extends ReversibleStep<bool> {
  @override
  Future<bool> capture(StepContext context) async {
    final CommandResult found = await context.shell.run(
      kubectl.observing(<String>['get', 'namespace', namespace, '-o', 'name']),
    );
    return found.ok;
  }

  @override
  Future<void> undo(StepContext context, bool captured) async {
    if (captured) {
      return;
    }
    await _remove(context);
  }

  Future<void> _remove(StepContext context) async {
    await context.shell.run(
      kubectl.command(<String>['delete', 'namespace', namespace, '--ignore-not-found']),
    );
  }
}
''';

      final List<Finding> found = CapturedRefusal.findingsIn(
        planted,
        'lib/kubernetes_namespace.dart',
      );

      expect(found, hasLength(1));
      expect(found.single.line, 7);
    });

    test('WHAT THE UNDO DOES BEFORE IT LOOKS AT THE VALUE IS NOT THE VALUE\'S DOING', () {
      // git_merge_ref. The abort runs whatever the capture answered, so it carries no refusal — it
      // is the step cleaning up its own partial apply. A scan asking only "can this undo touch the
      // machine" would report this place, and its only fix would be to stop aborting the merge.
      const String planted = '''
final class GitMergeRef extends ReversibleStep<String?> {
  @override
  Future<String?> capture(StepContext context) async {
    final CommandResult head = await context.shell.run(
      Command.observing('git', arguments: <String>['-C', repository, 'rev-parse', 'HEAD']),
    );
    return head.ok && head.trimmed.isNotEmpty ? head.trimmed : null;
  }

  @override
  Future<void> undo(StepContext context, String? captured) async {
    if (await _inProgress(context)) {
      await _mustRun(context, <String>['-C', repository, 'merge', '--abort']);
    }
    if (captured == null) {
      return;
    }
    await _mustRun(context, <String>['-C', repository, 'reset', '--hard', captured]);
  }
}
''';

      final ({List<Capture> captures, List<Instruction> instructions, List<Finding> findings})
      judged = CapturedRefusal.judgementOf(planted, 'lib/git_merge_ref.dart');

      expect(judged.findings, isEmpty);
      expect(judged.instructions, hasLength(1));
      expect(judged.instructions.single.undoActs, isFalse);
    });

    test('A CAPTURE THAT NAMES ITS REFUSAL FOLDS NOTHING, however the undo is written', () {
      // The treatment most of the tree carries: a record with a refusal beside the value. The
      // branch answers a call, so no bare value travels and there is nothing to hold against the
      // undo — which here deletes on the very half a fold would have produced.
      const String planted = '''
final class OidcAdminsBinding extends ReversibleStep<bool> {
  @override
  Future<bool> capture(StepContext context) async {
    final ({String? answer, String? refusal}) read = await kubectl.readOne(
      context,
      kind: 'clusterrolebinding',
      name: name,
    );
    if (read.refusal case final String refusal) {
      context.log.warn('whether \$name was there could not be read: \$refusal');
      return true;
    }
    return read.answer != null;
  }

  @override
  Future<void> undo(StepContext context, bool captured) async {
    if (captured) {
      return;
    }
    await context.shell.run(kubectl.command(<String>['delete', 'clusterrolebinding', name]));
  }
}
''';

      final ({List<Capture> captures, List<Instruction> instructions, List<Finding> findings})
      judged = CapturedRefusal.judgementOf(planted, 'lib/oidc_admins_binding.dart');

      expect(judged.findings, isEmpty);
      expect(judged.instructions, isEmpty);
      expect(judged.captures, hasLength(1), reason: 'the pair is still counted as one it judged');
    });

    test('A CHECK IS NOT A CAPTURE: the same fold in the step\'s own check is not this rule\'s', () {
      // replace_regex_in_tracked_file, which the ticket listed and which folds nothing at all: its
      // capture is empty, and the reading it makes stands in the check, where a refusal blocks. The
      // sibling rule is what judges that half.
      const String planted = '''
final class ReplaceRegexInTrackedFile extends ReversibleStep<void> {
  @override
  Future<void> capture(StepContext context) async {}

  @override
  Future<CheckResult> check(StepContext context) async {
    final CommandResult found = await context.shell.run(
      Command.observing('grep', arguments: <String>['-q', '-E', pattern, path]),
    );
    if (!found.ok) {
      return const CheckResult.ready();
    }
    return const CheckResult.satisfied('the pattern is not in the file');
  }

  @override
  Future<void> undo(StepContext context, void captured) async {
    await context.shell.run(
      Command.detailed('git', arguments: <String>['checkout', '--', path]),
    );
  }
}
''';

      expect(CapturedRefusal.findingsIn(planted, 'lib/replace_regex.dart'), isEmpty);
    });

    test('A PAIR WHOSE UNDO THIS SCAN CANNOT READ IS COUNTED, NEVER PASSED OVER IN SILENCE', () {
      // The one shape that must never come back as a clean answer. The undo tests the captured
      // value in a way this scan has no entry for, so what it does on a refusal is unknown — and
      // saying so is the difference between a scan that decided and a scan that looked away.
      const String planted = '''
final class WriteThing extends ReversibleStep<String?> {
  @override
  Future<String?> capture(StepContext context) async {
    final CommandResult read = await context.shell.run(command);
    if (!read.ok) {
      return null;
    }
    return read.trimmed;
  }

  @override
  Future<void> undo(StepContext context, String? captured) async {
    if (captured?.length case final int held when held > 3) {
      return;
    }
    await context.files.delete(path);
  }
}
''';

      final ({List<Capture> captures, List<Instruction> instructions, List<Finding> findings})
      judged = CapturedRefusal.judgementOf(planted, 'lib/write_thing.dart');

      expect(judged.findings, isEmpty);
      expect(judged.instructions, hasLength(1));
      expect(judged.instructions.single.undoActs, isNull);
    });

    test('THE FILES PORT IS NOT JUDGED, and the shape it would have been judged by is planted '
        'here', () {
      // create_file_from_template, one of the eight measured sites. It folds exactly the defect
      // this rule is about — and it is silent here on purpose, because `Files.exists` answers one
      // boolean and there is no branch in this text a reader could be sent to. The day the port
      // learns to say it could not look, this planted text is what has to go red.
      const String planted = '''
final class CreateFileFromTemplate extends ReversibleStep<bool> {
  @override
  Future<bool> capture(StepContext context) =>
      context.files.exists(pathFor(context), elevated: elevated);

  @override
  Future<void> undo(StepContext context, bool captured) async {
    if (captured) {
      return;
    }
    await context.files.delete(pathFor(context), elevated: elevated);
  }
}
''';

      final ({List<Capture> captures, List<Instruction> instructions, List<Finding> findings})
      judged = CapturedRefusal.judgementOf(planted, 'lib/create_file_from_template.dart');

      expect(judged.findings, isEmpty);
      expect(judged.instructions, isEmpty);
      expect(
        judged.captures,
        hasLength(1),
        reason: 'the pair is counted, so the hole is a number rather than an absence',
      );
    });

    // A REGION IS FOUND BY COUNTING BRACES, so it is counted over `codeOf` and never over the file
    // as written. Each of the two below reports the wrong thing the moment that stops being true,
    // and they fail in opposite directions.
    test('a brace inside a comment does not carry a guard of the undo past its own end', () {
      // The loud one: counted over the raw text, the brace in the comment runs the guarded region
      // past its closing brace and swallows the write below it, so a step whose undo returns on the
      // refusal is reported — and the only fix a reader can see is to delete the comment. The
      // count is asserted BESIDE the silence, because the same brace also stops the class from
      // closing, and a file nothing was found in reads exactly like a file nothing is wrong with.
      const String planted = '''
final class SetProcessFlag extends ReversibleStep<String?> {
  @override
  Future<String?> capture(StepContext context) async {
    final CommandResult read = await context.shell.run(command);
    if (!read.ok) {
      return null;
    }
    return read.trimmed;
  }

  @override
  Future<void> undo(StepContext context, String? captured) async {
    if (captured == null) {
      // Whatever owns the process writes these files when it is installed, so a { written here
      // would leave a service started with arguments nothing on the machine put there.
      return;
    }
    await context.files.write(argsPath, captured, mode: fileMode);
  }
}
''';

      final ({List<Capture> captures, List<Instruction> instructions, List<Finding> findings})
      judged = CapturedRefusal.judgementOf(planted, 'lib/set_process_flag.dart');

      expect(judged.findings, isEmpty);
      expect(
        judged.captures,
        hasLength(1),
        reason:
            'the pair has to have been FOUND for the silence above to mean anything — the same '
            'brace that would swallow the write also stops the class from closing, and then '
            'nothing is judged at all',
      );
      expect(judged.instructions.single.undoActs, isFalse);
    });

    test('a brace inside a string does not end a branch of the capture before the value it '
        'answers', () {
      // The silent one, and the worse of the two: counted over the raw text the brace inside the
      // warning ends the branch before the `return null` below it, so the fold is never seen — and
      // the file goes on being counted among the files this scan judged, with the pair counted as
      // one it decided.
      const String planted = r'''
final class WriteContainerdRegistryMirror extends ReversibleStep<String?> {
  @override
  Future<String?> capture(StepContext context) async {
    final CommandResult read = await context.shell.run(command);
    if (!read.ok) {
      context.log.warn('the mirror answered with nothing but a brace }');
      return null;
    }
    return read.trimmed;
  }

  @override
  Future<void> undo(StepContext context, String? captured) async {
    if (captured == null) {
      await context.files.delete(path);
      return;
    }
    await context.files.write(path, captured, mode: fileMode);
  }
}
''';

      final List<Finding> found = CapturedRefusal.findingsIn(planted, 'lib/mirror.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 5);
    });

    test('a class holding two captures is not judged, and is not counted either', () {
      // Which undo a capture instructs would be a guess, and this scan does not guess. It is left
      // out of the population as well, so a tree of such classes cannot read as a tree that was
      // judged and found clean.
      const String planted = '''
final class TwoCaptures extends ReversibleStep<bool> {
  Future<bool> capture(StepContext context) async {
    final CommandResult read = await context.shell.run(command);
    return read.ok;
  }

  Future<bool> capture(StepContext context, String which) async {
    final CommandResult read = await context.shell.run(command);
    return read.ok;
  }

  Future<void> undo(StepContext context, bool captured) async {
    if (captured) {
      return;
    }
    await context.shell.run(remove);
  }
}
''';

      final ({List<Capture> captures, List<Instruction> instructions, List<Finding> findings})
      judged = CapturedRefusal.judgementOf(planted, 'lib/two_captures.dart');

      expect(judged.captures, isEmpty);
      expect(judged.findings, isEmpty);
    });

    test('a capture in one class is never held against the undo of another', () {
      // Two steps in one file, and the guard that keeps the pair honest: the folding capture stands
      // beside an undo that returns on the refusal, and the deleting undo stands beside a capture
      // that folds nothing. Paired by position rather than by class, this file would be reported.
      const String planted = '''
final class LeavesAlone extends ReversibleStep<bool> {
  Future<bool> capture(StepContext context) async {
    final CommandResult read = await context.shell.run(command);
    return read.ok;
  }

  Future<void> undo(StepContext context, bool captured) async {
    if (captured) {
      return;
    }
    return;
  }
}

final class Deletes extends ReversibleStep<bool> {
  Future<bool> capture(StepContext context) async => true;

  Future<void> undo(StepContext context, bool captured) async {
    if (captured) {
      return;
    }
    await context.shell.run(remove);
  }
}
''';

      final ({List<Capture> captures, List<Instruction> instructions, List<Finding> findings})
      judged = CapturedRefusal.judgementOf(planted, 'lib/two_steps.dart');

      expect(judged.captures, hasLength(2));
      expect(judged.findings, isEmpty);
    });

    test('a scan over a tree reads every file of it and states what it held', () {
      // The whole-tree entry point, which is what an audit runs. The per-file entry point above
      // cannot show that the file list, the captures and the findings are read off the same tree.
      final SourceTree planted = SourceTree.planted(<String, String?>{
        'pubspec.yaml': 'name: planted_package\n',
        'lib/namespace.dart': '''
final class KubernetesNamespace extends ReversibleStep<bool> {
  @override
  Future<bool> capture(StepContext context) async {
    final CommandResult found = await context.shell.run(command);
    return found.ok;
  }

  @override
  Future<void> undo(StepContext context, bool captured) async {
    if (captured) {
      return;
    }
    await context.shell.run(remove);
  }
}
''',
        // Not text. A byte scan over an image reports matches nobody can act on, so a file holding
        // a zero byte is counted as present and left unread.
        'lib/logo.png': null,
      });

      final CapturedRefusal scan = CapturedRefusal(tree: planted, scanned: const <String>['lib']);

      expect(scan.files, <String>['lib/namespace.dart']);
      expect(scan.captures, hasLength(1));
      expect(scan.captures.single.step, 'KubernetesNamespace');
      expect(scan.instructions, hasLength(1));
      expect(scan.unread, isEmpty);
      expect(scan.findings, hasLength(1));
      expect(scan.findings.single.subject, 'lib/namespace.dart');
    });
  });
}

/// The places [instructions] stand, in the words a reader opens them with.
String _named(List<Instruction> instructions) =>
    instructions.map((Instruction each) => '${each.path}:${each.line} (${each.step})').join(', ');
