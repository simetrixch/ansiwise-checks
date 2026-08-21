/// The suite that drives [Reversibility] over one registry and tree, with its counter-probe.
library;

import 'package:ansiwise_core/ansiwise_core.dart';
import 'package:test/test.dart';

import 'package:ansiwise_checks_tree/ansiwise_checks_tree.dart';
import '../registry_completeness.dart';
import '../registry_reading.dart';
import '../reversibility.dart';

/// Runs the reversibility audit over [registry] and [tree].
///
/// WHAT IT STATES: how many entries were read, how many of them cannot be taken back, and how many of
/// those are an exchange. The second is the denominator of the half that has teeth — a reading in
/// which nothing is irreversible holds the placeholder rule against nothing. The third is the
/// denominator of the rule that an exchange has something to publish, and it is separate because that
/// rule reaches no other kind.
void auditReversibility(Registry registry, {SourceTree? tree}) {
  final SourceTree judged = tree ?? SourceTree.on(repositoryRoot());
  final RegistryReading reading = RegistryReading.of(registry);
  final Reversibility check = Reversibility(tree: judged, reading: reading);
  final int entries = reading.entries.length;
  final int irreversible = check.irreversibleEntries.length;
  final int exchanges = check.exchangeEntries.length;

  test('$entries entry/entries were read, $irreversible of which cannot be taken back, '
      '$exchanges of those an exchange', () {
    expect(
      reading.entries,
      isNotEmpty,
      reason: "no registry entry was read at all, so no step's kind was measured",
    );
  });

  test('every registered step is reversible, irreversible, observing or an exchange', () {
    expect(
      check.findings,
      isEmpty,
      reason:
          'a step that answers neither leaves a dry run unable to say whether it has passed the '
          'point of no return, and an irreversible one has to say what is lost',
    );
  });

  group('counter-probe', () {
    // The placeholder judgement, from both sides. Only the second half has teeth in a tree whose
    // reasons are all good: a rule that called everything a placeholder would turn every
    // irreversible step red, and a rule that called nothing one is the state this check would rot
    // into.

    for (final String planted in <String>[
      'todo',
      'TODO',
      'n/a',
      'none',
      'not implemented',
      'No undo implemented',
      'undo not implemented',
      'cannot be undone.',
      'irreversible',
      '   ',
    ]) {
      test('"$planted" is not accepted as a reason', () {
        expect(
          reasonIsAPlaceholder(planted),
          isTrue,
          reason: 'a step that says nothing about what is lost would pass',
        );
      });
    }

    for (final String planted in _reasonsThatSayWhatIsLost) {
      test('a reason that says what is lost is left alone', () {
        expect(
          reasonIsAPlaceholder(planted),
          isFalse,
          reason: 'this check refuses a real reason, so every irreversible step would be red',
        );
      });
    }

    // The direct-extension scan, over a tree this audit plants: the violation must be reported and
    // the three kinds must not, or the scan would turn the framework's own step.dart red.
    final SourceTree planted = SourceTree.planted(<String, String>{
      'pubspec.yaml': 'name: planted_package\n',
      'lib/src/domain/step.dart': _plantedKinds,
    });
    final Iterable<String> reported = classesExtendingStepItself(
      planted,
    ).map((DeclaredStepClass declared) => declared.className);

    test('a planted class extending Step itself is reported', () {
      expect(reported, contains('PlantedDirect'), reason: 'this scan cannot go red');
    });

    for (final String allowed in <String>[...theThreeKinds, 'PlantedProper']) {
      test('$allowed is not reported', () {
        expect(
          reported,
          isNot(contains(allowed)),
          reason: 'this scan refuses the very shape every step has',
        );
      });
    }

    test('an irreversible step whose reason says nothing is reported', () {
      final Reversibility onPlanted = Reversibility(
        tree: planted,
        reading: RegistryReading.of(_registryOf(const _SaysNothingIsLost())),
      );
      expect(
        about(onPlanted.findings, 'planted'),
        isNotEmpty,
        reason: 'a placeholder compiles and reads like an answer, which is why it needs a check',
      );
    });

    test('an irreversible step that says what is lost is left alone', () {
      final Reversibility onPlanted = Reversibility(
        tree: planted,
        reading: RegistryReading.of(_registryOf(const _SaysWhatIsLost())),
      );
      expect(
        about(onPlanted.findings, 'planted'),
        isEmpty,
        reason: 'this check reports every irreversible step, so its silence means nothing',
      );
    });

    // The exchange, from both sides. Its kind is told apart from an ordinary irreversible step, and
    // it owes one thing more than a reason: something to publish. A postcondition over an empty set
    // holds vacuously, so an exchange with nothing to publish has no postcondition at all — the
    // request goes out and the row is a success with nothing to show for it.

    test('an exchange is read as its own kind and still owes a reason', () {
      final RegistryReading read = RegistryReading.of(
        _registryOf(const _MintsAValue(), publishes: _mintedValue),
      );

      expect(read.entries.single.kind, StepKind.exchange);
      expect(
        Reversibility(tree: planted, reading: read).irreversibleEntries,
        hasLength(1),
        reason:
            'the other end was told and only it knows its own inverse, so an exchange is one of the '
            'entries that cannot be taken back',
      );
    });

    test('an exchange whose reason says nothing is reported, exactly as any other is', () {
      final Reversibility onPlanted = Reversibility(
        tree: planted,
        reading: RegistryReading.of(
          _registryOf(const _MintsWithoutSayingWhatIsLost(), publishes: _mintedValue),
        ),
      );

      expect(about(onPlanted.findings, 'planted'), isNotEmpty);
    });

    test('an exchange with nothing to publish is reported', () {
      final Reversibility onPlanted = Reversibility(
        tree: planted,
        reading: RegistryReading.of(_registryOf(const _MintsAValue())),
      );

      expect(
        about(onPlanted.findings, 'planted').map((Finding found) => found.what),
        contains(contains('publishes nothing, so the postcondition')),
      );
    });

    test('THE INNOCENT NEIGHBOUR: an exchange that publishes is left alone', () {
      // Without this, a rule that reported every exchange would satisfy the probe above and turn
      // every honest one red.
      final Reversibility onPlanted = Reversibility(
        tree: planted,
        reading: RegistryReading.of(_registryOf(const _MintsAValue(), publishes: _mintedValue)),
      );

      expect(about(onPlanted.findings, 'planted'), isEmpty);
    });
  });
}

/// What a planted exchange says it publishes, which is what gives it a postcondition at all.
const List<MeasurementSpec> _mintedValue = <MeasurementSpec>[
  MeasurementSpec(name: MeasurementName('minted_value'), describes: 'what the other end minted'),
];

/// Three reasons that really say what an operator loses, written without naming any one tool.
///
/// A probe made of one product's sentences proves the rule on that product's wording; these are the
/// three shapes an honest reason has — the old value is not recorded, the previous one was not kept,
/// and what a thing held is gone with it.
const List<String> _reasonsThatSayWhatIsLost = <String>[
  'the target now runs the new revision, and what the old one had written is not recorded anywhere',
  'the values it was running with are replaced, and nothing kept the previous ones',
  'the objects it created are deleted, and what they held is gone with them',
];

/// The three kinds and two planted classes, as the lines of one file.
///
/// Written as a list of lines rather than as one multi-line string, because this file is itself
/// scanned by the check it holds wherever it is resolved from: a line reading `class X extends Step`
/// at column zero would be a declaration as far as that scan is concerned, and the tree holding this
/// file would go red.
final String _plantedKinds = <String>[
  'abstract base class ReversibleStep extends Step {',
  'abstract base class IrreversibleStep extends Step {',
  'abstract base class ObservingStep extends Step {',
  'final class PlantedDirect extends Step {',
  'final class PlantedProper extends ObservingStep {',
].join('\n');

/// A registry holding [step] under the name `planted` and nothing else.
Registry _registryOf(Step step, {List<MeasurementSpec> publishes = const <MeasurementSpec>[]}) =>
    Registry(
      steps: <StepName, RegisteredStep>{
        const StepName('planted'): RegisteredStep(
          name: const StepName('planted'),
          source: 'lib/src/steps/planted.dart:1',
          create: (Arguments arguments) => step,
          publishes: publishes,
        ),
      },
      predicates: const <PredicateName, RegisteredPredicate>{},
    );

/// A step that cannot be taken back and says so with a word instead of a reason.
final class _SaysNothingIsLost extends IrreversibleStep {
  const _SaysNothingIsLost();

  @override
  String get irreversibleReason => 'not implemented';

  @override
  Future<CheckResult> check(StepContext context) async => const CheckResult.ready();

  @override
  Future<StepPlan> plan(StepContext context) async => const StepPlan.nothing('nothing to do');

  @override
  Future<void> apply(StepContext context) async {}
}

/// A step whose one request mints a value, and whose answer is the whole of what it did.
final class _MintsAValue extends ExchangeStep {
  const _MintsAValue();

  @override
  String get irreversibleReason =>
      'the other end minted a value and there is no request that unmints it';

  @override
  Future<CheckResult> check(StepContext context) async => const CheckResult.ready();

  @override
  Future<StepPlan> plan(StepContext context) async => const StepPlan.nothing('would ask for one');

  @override
  Future<void> apply(StepContext context) async {}
}

/// An exchange that answers the question of being taken back with a word instead of a reason.
final class _MintsWithoutSayingWhatIsLost extends ExchangeStep {
  const _MintsWithoutSayingWhatIsLost();

  @override
  String get irreversibleReason => 'not implemented';

  @override
  Future<CheckResult> check(StepContext context) async => const CheckResult.ready();

  @override
  Future<StepPlan> plan(StepContext context) async => const StepPlan.nothing('would ask for one');

  @override
  Future<void> apply(StepContext context) async {}
}

/// A step that cannot be taken back and says what an operator loses by going on.
final class _SaysWhatIsLost extends IrreversibleStep {
  const _SaysWhatIsLost();

  @override
  String get irreversibleReason => _reasonsThatSayWhatIsLost.first;

  @override
  Future<CheckResult> check(StepContext context) async => const CheckResult.ready();

  @override
  Future<StepPlan> plan(StepContext context) async => const StepPlan.nothing('nothing to do');

  @override
  Future<void> apply(StepContext context) async {}
}
