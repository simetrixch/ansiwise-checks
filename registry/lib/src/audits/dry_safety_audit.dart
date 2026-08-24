/// The suite that drives [DrySafety] over one registry, with its counter-probe.
library;

import 'package:ansiwise_checks_tree/ansiwise_checks_tree.dart';
import 'package:ansiwise_core/ansiwise_core.dart';
import 'package:test/test.dart';

import '../declared_answers.dart';
import '../dry_safety.dart';

/// Runs the dry-safety audit over [registry].
///
/// [answeringOnTrust] is the exact list of steps whose answer rests on the program row's word. It is
/// WRITTEN OUT by the package rather than derived from the steps, and that is the point: for such a
/// step the dry-run guarantee is the row's claim and not the framework's, so a step that begins
/// taking the row's word has to be named by a person before this audit will pass.
///
/// [answers] is what a program file would give the steps. Left out, it is read from what the
/// installation's programs declare for the answers THIS registry's steps say they read — which is
/// nothing at all for a registry whose steps read none, and then no installation tree is opened.
///
/// WHAT IT STATES: how many steps were asked, under how many argument settings and how many of them
/// under both values of a flag they declare with no value of its own, how many produced a plan or
/// were refused with nothing reaching the machine, and which ones answered on the row's word. A
/// reading that covered no step would leave every assertion unmade and the audit would be green for
/// having looked at nothing — and one that reached only one half of every flag would be green for
/// having looked at half of each step.
Future<void> auditDrySafety(
  Registry registry, {
  required List<String> answeringOnTrust,
  Arguments? answers,
}) async {
  // SKIPPED WHERE THERE IS NO INSTALLATION TO READ, printed rather than passed over. What this
  // audit measures is a registry against the ANSWERS a real installation declares, and that tree is
  // a sibling checkout: it stands beside a developer's clone and beside nothing on a release
  // runner. Reaching for it there threw while the suite was still LOADING, which took the whole
  // gate down over one check that could not be measured — a release refused for a reason that says
  // nothing about the release.
  if (!installationIsFindable) {
    test('dry-safety', () {}, skip: installationNotFound);
    return;
  }

  final DrySafety check = DrySafety(
    registry: registry,
    answers: answers ?? (await answersDeclaredBy(registry)).values,
  );
  final DryRunReading reading = await check.askEveryStep();

  test('${reading.outcomes.length} of ${registry.steps.length} step(s) were asked what they '
      'would do, over ${reading.asks} argument setting(s), ${reading.askedBothWays.length} step(s) '
      'of them under both values of a flag they declare with no value of its own', () {
    expect(
      reading.outcomes,
      hasLength(registry.steps.length),
      reason: 'some step was never asked, so nothing about its dry run was measured',
    );
  });

  test('no registered step can complete a mutation under --mode dry', () {
    expect(
      reading.findings,
      isEmpty,
      reason:
          'each of these either produced a StepPlan or was refused by a port, and no command that '
          'changes something, no write, no delete and no request that is not a read reached the '
          'machine behind them',
    );
  });

  test(
    '${reading.safeCount} step(s) planned or were refused with nothing reaching the machine',
    () {
      expect(
        reading.safeCount,
        greaterThan(0),
        reason: 'not one step got as far as a plan or a refusal, so the ports were never exercised',
      );
    },
  );

  test("${reading.onTrust.length} step(s) answer on the row's word, and are not counted safe", () {
    // For such a step the dry-run guarantee is the row's claim, not the framework's: the row names
    // the command and declares that it only looks, and nothing here chose or verified it. So the
    // audit states the list for somebody to read instead of counting them among the safe ones —
    // this assertion is exact, so a new step that takes the row's word has to be named to pass.
    expect(
      reading.onTrust,
      answeringOnTrust,
      reason:
          'either a step whose answer rests on the row went uncounted, or one was counted safe on a '
          'claim the framework cannot verify',
    );
  });

  group('counter-probe', () {
    // Four steps written here, run through the same machinery, one per method a dry run drives. A
    // step that writes from its check, one that runs a changing command from its plan and one that
    // writes from its CAPTURE must all three come back refused; a step that only looks must come
    // back with a plan, because a check that reported everything would satisfy the first three
    // alone.

    test('a write from inside a check is refused', () async {
      expect(
        await _ask(const WritesFromItsCheck(), wrapInPlanningPorts: true),
        isA<RefusedByAPort>(),
        reason: 'a step planted here wrote a file from its check and was not stopped',
      );
    });

    test('a changing command from inside a plan is refused', () async {
      expect(
        await _ask(const RunsAChangingCommandFromItsPlan(), wrapInPlanningPorts: true),
        isA<RefusedByAPort>(),
        reason: 'a step planted here ran a changing command from its plan and was not stopped',
      );
    });

    // The request half. A package whose steps reach their tool over HTTP rather than through a
    // shell has mutations that are a POST and not a command, and the shell probes above say nothing
    // whatever about those.
    test('a request that is not a read is refused', () async {
      expect(
        await _ask(const SendsARequestFromItsPlan(), wrapInPlanningPorts: true),
        isA<RefusedByAPort>(),
        reason: 'a step planted here sent a POST from its plan and was not stopped',
      );
    });

    test('a request that got through is seen', () async {
      expect(
        await _ask(const SendsARequestFromItsPlan(), wrapInPlanningPorts: false),
        isA<ReachedTheMachine>(),
        reason:
            'the same step ran with the planning ports taken off, the request reached the fake '
            'machine, and nothing noticed',
      );
    });

    test('a write from inside a capture is refused', () async {
      expect(
        await _ask(const WritesFromItsCapture(), wrapInPlanningPorts: true),
        isA<RefusedByAPort>(),
        reason: 'a step planted here wrote a file from its capture and was not stopped',
      );
    });

    // What says the capture is DRIVEN at all, and not merely refused-by-absence. With the planning
    // ports off the write reaches the fake, so this is red both when the ports stop refusing and
    // when the audit stops calling `capture` — and the test above cannot tell those apart on its
    // own, because a capture nobody calls also produces no finding.
    test('a capture that got through is seen', () async {
      expect(
        await _ask(const WritesFromItsCapture(), wrapInPlanningPorts: false),
        isA<ReachedTheMachine>(),
        reason:
            'the capture ran with the planning ports taken off and nothing noticed — so either the '
            'evidence is not gathered or the capture is never driven',
      );
    });

    test("a step that answers on the row's word is reported as on trust, not as safe", () async {
      expect(
        await _ask(const AnswersOnTheRowsWord(), wrapInPlanningPorts: true),
        isA<AnsweredOnTrust>(),
        reason:
            'a step planted here says its answer rests on the row and came back counted as an '
            'ordinary plan, so the list an operator reads would miss it',
      );
    });

    test('a step that only looks is left alone', () async {
      expect(
        await _ask(const OnlyLooks(), wrapInPlanningPorts: true),
        isA<ProducedAPlan>(),
        reason: 'a step planted here only read the machine and was reported anyway',
      );
    });

    // The one that matters most. It runs the writing step WITHOUT the planning ports, so the write
    // does reach the fake, and it fails unless that is reported. That is what separates "the ports
    // refused it" from "nothing was looking": weaken PlanningFiles.write from a refusal into a shrug
    // and the first test above goes red, delete the evidence-gathering and this one does.
    test('a mutation that got through is seen', () async {
      expect(
        await _ask(const WritesFromItsCheck(), wrapInPlanningPorts: false),
        isA<ReachedTheMachine>(),
        reason:
            'the same writing step ran with the planning ports taken off, the write reached the '
            'fake machine, and nothing noticed — so an empty finding proves nothing',
      );
    });

    test('the evidence names what reached the machine', () async {
      final DryRunOutcome outcome = await _ask(
        const WritesFromItsCheck(),
        wrapInPlanningPorts: false,
      );
      expect(
        (outcome as ReachedTheMachine).evidence,
        contains(contains(WritesFromItsCheck.path)),
        reason: 'a finding that does not say what was changed is one nobody can act on',
      );
    });

    test('the write only the elevated branch makes is reached, and refused there', () async {
      // THE SETTING THE PROBE NEVER HANDED ANY STEP. Under `elevated: false` this one only looks,
      // so a run that drove that value alone exercised the ports against a step that never asked
      // anything of them — and the branch a whole deployment actually runs, since the
      // installation's own program sets `elevated: true` for every row of it, met nothing.
      expect(
        await _ask(const WritesOnlyWhenElevated(elevated: false), wrapInPlanningPorts: true),
        isA<ProducedAPlan>(),
        reason: 'the unelevated branch of this step only looks, and was reported as something else',
      );
      expect(
        await _ask(const WritesOnlyWhenElevated(elevated: true), wrapInPlanningPorts: true),
        isA<RefusedByAPort>(),
        reason:
            'the elevated branch writes from its check, and a dry run that neither refused it nor '
            'reported it never reached that branch at all',
      );
    });

    test('a step that can only answer in one of its branches is asked in both', () async {
      // What the reading reports when the two settings disagree: the step is as unsafe as its worst
      // one, and the finding names WHICH value of the flag it was under.
      final DryRunReading reading = await _readingOf(
        (Arguments arguments) => CannotAnswerWhenElevated(elevated: arguments.flag('elevated')),
      );

      expect(reading.settings['planted'], 2);
      expect(reading.outcomes['planted'], isA<NeitherPlannedNorRefused>());
      expect(reading.findings.single.what, contains('elevated: true'));
    });

    test('THE INNOCENT NEIGHBOUR: a step that only looks under both is left alone', () async {
      final DryRunReading reading = await _readingOf((Arguments arguments) => const OnlyLooks());

      expect(reading.settings['planted'], 2);
      expect(reading.outcomes['planted'], isA<ProducedAPlan>());
      expect(reading.findings, isEmpty);
    });
  });
}

/// The whole audit run over one planted step that declares the elevation, and nothing else.
///
/// A registry rather than a bare step, because what is being probed is the part that decides how
/// many times a step is asked and what it is handed each time.
Future<DryRunReading> _readingOf(Step Function(Arguments arguments) create) => DrySafety(
  registry: Registry(
    steps: <StepName, RegisteredStep>{
      const StepName('planted'): RegisteredStep(
        name: const StepName('planted'),
        source: 'lib/planted.dart:1',
        create: create,
        arguments: const <ArgumentSpec>[elevationArgument],
      ),
    },
    predicates: const <PredicateName, RegisteredPredicate>{},
  ),
).askEveryStep();

/// A step that only looks where the row granted no elevation, and writes where it did.
final class WritesOnlyWhenElevated extends IrreversibleStep {
  /// Creates the planted step, writing from its check where [elevated].
  const WritesOnlyWhenElevated({required this.elevated});

  /// Where it writes, so a counter-probe can name what got through.
  static const String path = '/etc/planted-as-root';

  /// Whether the row granted elevation.
  final bool elevated;

  @override
  String get irreversibleReason => 'it is a probe and is never run against a machine';

  @override
  Future<CheckResult> check(StepContext context) async {
    if (elevated) {
      await context.files.write(path, 'written from a check', mode: 0x180, elevated: elevated);
    }
    return const CheckResult.ready();
  }

  @override
  Future<StepPlan> plan(StepContext context) async => const StepPlan.nothing('would look');

  @override
  Future<void> apply(StepContext context) async {}
}

/// A step that cannot say what it would do where the row granted elevation.
///
/// Neither planned nor refused is the outcome nobody can act on: what such a step would do to a
/// machine is unknown, and a run that only ever drove the other branch reports it as safe.
final class CannotAnswerWhenElevated extends IrreversibleStep {
  /// Creates the planted step, unable to plan where [elevated].
  const CannotAnswerWhenElevated({required this.elevated});

  /// Whether the row granted elevation.
  final bool elevated;

  @override
  String get irreversibleReason => 'it is a probe and is never run against a machine';

  @override
  Future<CheckResult> check(StepContext context) async => const CheckResult.ready();

  @override
  Future<StepPlan> plan(StepContext context) async {
    if (elevated) {
      throw StateError('this branch does not know what it would change');
    }
    return const StepPlan.nothing('would look');
  }

  @override
  Future<void> apply(StepContext context) async {}
}

Future<DryRunOutcome> _ask(Step step, {required bool wrapInPlanningPorts}) => askWhatItWouldDo(
  const StepName('planted'),
  step,
  Arguments.none,
  wrapInPlanningPorts: wrapInPlanningPorts,
);

/// A step that changes something from the one method a dry run always calls.
final class WritesFromItsCheck extends IrreversibleStep {
  /// Creates the planted step.
  const WritesFromItsCheck();

  /// Where it writes, so a counter-probe can name what got through.
  static const String path = '/etc/planted';

  @override
  String get irreversibleReason => 'it is a probe and is never run against a machine';

  @override
  Future<CheckResult> check(StepContext context) async {
    await context.files.write(path, 'written from a check', mode: 0x180);
    return const CheckResult.ready();
  }

  @override
  Future<StepPlan> plan(StepContext context) async =>
      const StepPlan.nothing('never reached, because the check writes first');

  @override
  Future<void> apply(StepContext context) async {}
}

/// A step that changes something from the method a dry run calls instead of `apply`.
final class RunsAChangingCommandFromItsPlan extends IrreversibleStep {
  /// Creates the planted step.
  const RunsAChangingCommandFromItsPlan();

  @override
  String get irreversibleReason => 'it is a probe and is never run against a machine';

  @override
  Future<CheckResult> check(StepContext context) async => const CheckResult.ready();

  @override
  Future<StepPlan> plan(StepContext context) async {
    await context.shell.run(const Command('rm', <String>['-rf', '/planted']));
    return const StepPlan.argv(<String>['rm', '-rf', '/planted']);
  }

  @override
  Future<void> apply(StepContext context) async {}
}

/// A step that changes something over HTTP, which is how a step reaches a tool that has no command.
final class SendsARequestFromItsPlan extends IrreversibleStep {
  /// Creates the planted step.
  const SendsARequestFromItsPlan();

  /// Where it posts, so a counter-probe can name what got through.
  static const String url = 'http://127.0.0.1:9/planted';

  @override
  String get irreversibleReason => 'it is a probe and is never run against a machine';

  @override
  Future<CheckResult> check(StepContext context) async => const CheckResult.ready();

  @override
  Future<StepPlan> plan(StepContext context) async {
    await context.http.send(const HttpRequest('POST', url, body: '{}'));
    return const StepPlan.nothing('would post to the tool');
  }

  @override
  Future<void> apply(StepContext context) async {}
}

/// A step that changes something from the method NOBODY thinks of as running under a dry run.
///
/// The capture is the third thing a dry run drives, and it is the one that is easy to leave out — it
/// exists to prepare an undo, so it does not read as part of the run. This probe is what says the
/// driving is really there: take the capture out of the audit and the test that runs this one
/// WITHOUT the planning ports goes red, because nothing would reach the fake.
final class WritesFromItsCapture extends ReversibleStep<bool> {
  /// Creates the planted step.
  const WritesFromItsCapture();

  /// Where it writes, so a counter-probe can name what got through.
  static const String path = '/etc/planted-by-a-capture';

  @override
  Future<CheckResult> check(StepContext context) async => const CheckResult.ready();

  @override
  Future<StepPlan> plan(StepContext context) async =>
      const StepPlan.diff(path, before: '', after: 'what this step would write');

  @override
  Future<void> apply(StepContext context) async {}

  /// Reads what was there by writing, which is the shape this probe exists to catch.
  ///
  /// A real one would be subtler — a capture that asks a tool which creates its own state file on
  /// the way to answering — but what has to be shown is that a port refuses whatever the capture
  /// reaches for, and one write shows that as well as a subtle one.
  @override
  Future<bool> capture(StepContext context) async {
    await context.files.write(path, 'written from a capture', mode: 0x180);
    return true;
  }

  @override
  Future<void> undo(StepContext context, bool captured) async {}
}

/// A step that runs a command a program row would name, so its answer rests on the row's word.
final class AnswersOnTheRowsWord extends ObservingStep {
  /// Creates the planted step.
  const AnswersOnTheRowsWord();

  @override
  bool get answersOnTrust => true;

  @override
  Future<CheckResult> check(StepContext context) async {
    await context.shell.run(
      const Command.detailed('planted', observes: true, timeout: Duration(seconds: 30)),
    );
    return const CheckResult.ready();
  }

  @override
  Future<StepPlan> plan(StepContext context) async =>
      const StepPlan.nothing('would ask what the row names');
}

/// A step that reads the machine and plans, which is what every step is meant to do.
///
/// Reversible, and its capture only reads — so this also says that driving the capture does not
/// report a step which was doing the right thing.
final class OnlyLooks extends ReversibleStep<String?> {
  /// Creates the planted step.
  const OnlyLooks();

  @override
  Future<CheckResult> check(StepContext context) async {
    await context.files.exists('/etc/planted');
    await context.shell.run(const Command.observing('true'));
    return const CheckResult.ready();
  }

  @override
  Future<StepPlan> plan(StepContext context) async =>
      const StepPlan.diff('/etc/planted', before: '', after: 'what this step would write');

  @override
  Future<void> apply(StepContext context) async {}

  @override
  Future<String?> capture(StepContext context) async =>
      await context.files.exists('/etc/planted') ? context.files.read('/etc/planted') : null;

  @override
  Future<void> undo(StepContext context, String? captured) async {}
}
