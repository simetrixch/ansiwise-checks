/// Building one registered step, and running it outside a run.
///
/// A check asks a step a question the engine would ask it — what would you plan, are you already
/// satisfied — without a runner, a record or a machine. What it needs for that is the same three
/// things every time: values for the arguments the step declares, somewhere for the step to say
/// things, and a [StepContext] holding a set of ports the check chose.
library;

import 'package:ansiwise_core/ansiwise_core.dart';
import 'package:ansiwise_core/testing.dart';

import 'package:ansiwise_checks_tree/ansiwise_checks_tree.dart';

/// Arranges [FakeShell], [FakeFiles] and [FakeHttp] for one step.
///
/// A blank fake cannot exercise most steps: it records a command and does not carry it out, so a
/// postcondition a real command would leave behind never becomes true. A fixture arranges the fake
/// the way the real machine would be, which is what lets a check measure the step at all.
///
/// The map of them belongs to the PLUGIN — which step needs which arrangement is knowledge about
/// that plugin's steps. Only the shape is here, because the audits take it as an argument.
typedef Fixture = void Function(FakeShell shell, FakeFiles files, FakeHttp http);

/// What a probe hands a step for a text argument with no default.
///
/// Named rather than written twice: a fixture arranges the fake for the values the CHECK hands the
/// step, so a fixture and [plausibleArguments] disagreeing about this one character is a fixture
/// that arranges the wrong file and a step that comes back not covered for no visible reason.
const String plausibleText = 'x';

/// The flags of [specs] whose declaration names no value of its own.
///
/// **A flag has two values and a step does different work under each, so one of them is not a
/// probe of that step — it is half of one.** Where the declaration names a default, the other half
/// is still reachable by a row but the default is what a program that says nothing runs with, and
/// that is the case worth probing. Where it names none, `false` is not a default and not a decision:
/// it is the simplest value of the kind, and handing it over silently is how a step that declared
/// the shared elevation, never read it, and ran unelevated on every machine passed every check.
///
/// Measured: the elevation argument declares no default, and the installation's own program sets
/// `elevated: true` for every row of a whole deployment. So the value a probe invented was the one
/// the product almost never runs with.
List<ArgumentSpec> flagsWithNoValueOfTheirOwn(List<ArgumentSpec> specs) => <ArgumentSpec>[
  for (final ArgumentSpec spec in specs)
    if (spec.kind == ArgumentKind.flag && spec.defaultValue == null && spec.allowed.isEmpty) spec,
];

/// Every set of values a step is worth driving under: one per combination of the flags it declares
/// with no value of their own, all of them false first.
///
/// The count is 2^n over those flags alone, which is one setting for a step that declares none and
/// two for a step that declares the elevation. Every other argument holds the same value in every
/// setting, for the reasons [plausibleArguments] gives.
List<Arguments> plausibleArgumentSettings(List<ArgumentSpec> specs) {
  final Map<String, Object> fixed = <String, Object>{};
  final List<ArgumentSpec> driven = flagsWithNoValueOfTheirOwn(specs);
  final Set<String> drivenNames = <String>{for (final ArgumentSpec spec in driven) spec.name};
  for (final ArgumentSpec spec in specs) {
    if (!drivenNames.contains(spec.name)) {
      fixed[spec.name] = _plausibleValueOf(spec);
    }
  }
  List<Map<String, Object>> settings = <Map<String, Object>>[<String, Object>{}];
  for (final ArgumentSpec spec in driven) {
    settings = <Map<String, Object>>[
      for (final Map<String, Object> each in settings)
        for (final bool value in <bool>[false, true]) <String, Object>{...each, spec.name: value},
    ];
  }
  return <Arguments>[
    for (final Map<String, Object> setting in settings)
      Arguments(<String, Object>{...fixed, ...setting}),
  ];
}

/// A value for every argument [specs] declares, driving each flag at its default.
///
/// What a caller that runs a step ONCE hands it — the first of [plausibleArgumentSettings], where
/// every flag with no value of its own stands false. A default wins wherever there is one, because
/// that is the value a program that says nothing about the argument would run with. Where the
/// declaration names the values it may hold, the first of them is taken: a step that DECIDES on such
/// a value refuses anything outside the set, correctly, and handing it the generic 'x' would measure
/// the probe rather than the step. Everything else gets the simplest value of its kind. No step may
/// read an argument it did not declare, so this is enough to build any of them that keeps to its own
/// declaration; one that does not fails to build, and a check reports that rather than passing over
/// the step.
Arguments plausibleArguments(List<ArgumentSpec> specs) => plausibleArgumentSettings(specs).first;

/// Which of [specs]' driven flags [values] holds, in the words a finding names them by.
///
/// Empty where the step declares none, so a finding about such a step reads exactly as it did before
/// there was more than one setting.
String describeSetting(Arguments values, List<ArgumentSpec> specs) => <String>[
  for (final ArgumentSpec spec in flagsWithNoValueOfTheirOwn(specs))
    '${spec.name}: ${values.flag(spec.name)}',
].join(', ');

Object _plausibleValueOf(ArgumentSpec spec) =>
    spec.defaultValue ??
    (spec.allowed.isNotEmpty ? spec.allowed.first : null) ??
    switch (spec.kind) {
      ArgumentKind.text => plausibleText,
      ArgumentKind.answerName => plausibleText,
      ArgumentKind.integer => 1,
      ArgumentKind.flag => false,
      ArgumentKind.textList => const <String>['x'],
      // A mapping is planted with one entry naming one answer, because that is the smallest
      // shape every step declaring one accepts. A step wanting more says so in its own refusal.
      ArgumentKind.mapping => const <String, Object?>{
        'X': <String, Object?>{'answer': plausibleText},
      },
    };

/// [given] with an answer standing under every name the probe's own arguments point at.
///
/// **An argument of kind [ArgumentKind.answerName] holds the NAME of an answer, and a step reading
/// it then reads that answer.** The probe fills such an argument with its own plausible text, so
/// unless the same text also stands among the answers, every step of that shape fails to build —
/// and the check reports a step that refused, which is a finding about this probe rather than about
/// the step.
///
/// Measured: a step whose row names the answer holding a mailbox came back as "its plan threw: the
/// step read an argument it did not declare", three layers away from the reason.
Arguments answersForProbe(Arguments given, List<ArgumentSpec> specs) {
  final Map<String, Object> planted = <String, Object>{
    for (final String name in given.names)
      if (given.raw(name) case final Object value) name: value,
  };
  for (final ArgumentSpec spec in specs) {
    if (spec.kind == ArgumentKind.answerName) {
      planted[plausibleText] = plausibleText;
    }
  }
  return Arguments(planted);
}

/// The step [entry] builds from [arguments], or null when it cannot be built from them.
///
/// [arguments] is one of [plausibleArgumentSettings] and the step is BUILT again for each of them,
/// rather than built once and re-run: what a row grants reaches a step through its factory, so a
/// factory that drops the value is invisible to anything that builds the step only one way.
///
/// [onFailure] is given a finding naming the step, the setting it was built under, and the reason.
/// Every throwable is caught, including an [Error]: a step that reads an argument it never declared
/// throws [ArgumentError], and that is precisely the defect worth reporting rather than letting one
/// entry end the walk and say nothing about the rest.
Step? buildStep(
  RegisteredStep entry,
  Arguments arguments,
  void Function(Finding failure) onFailure,
) {
  try {
    return entry.create(arguments);
  } on Object catch (failure) {
    final String setting = describeSetting(arguments, entry.arguments);
    onFailure(
      Finding(
        entry.name.value,
        'could not be built from the arguments it declares itself'
        '${setting.isEmpty ? '' : ', under $setting'}, so nothing about it was measured — $failure',
      ),
    );
    return null;
  }
}

/// The predicate [entry] holds, or null when it cannot be built at all.
///
/// TWO SHAPES, and the second is the one that cannot simply be read. A condition that reads nothing
/// is registered as an instance and is handed straight back. A GENERIC one is registered as a
/// factory plus the values it must be told, and it holds no instance until an installation binds it
/// — so it is bound here to [plausibleArguments] over its own declaration, which is what [buildStep]
/// does one function up and for the same reason: a check reading the unbound entry gets `Null` and
/// then measures that.
///
/// The binding is thrown away with the values. What is wanted is the CLASS, and a condition built
/// from its own declared kinds is the class its factory builds whatever the values were.
///
/// [onFailure] is given a finding naming the predicate and the reason. Every throwable is caught,
/// including an [Error]: a condition that reads a value it never declared throws [ArgumentError],
/// and that is the defect worth reporting rather than one entry ending the walk.
Predicate? buildPredicate(RegisteredPredicate entry, void Function(Finding failure) onFailure) {
  if (entry.predicate case final Predicate instance) {
    return instance;
  }
  try {
    return entry.boundTo(entry.name, plausibleArguments(entry.arguments)).predicate;
  } on Object catch (failure) {
    onFailure(
      Finding(
        entry.name.value,
        'could not be built from the values it declares itself, so nothing about it was '
        'measured — $failure',
      ),
    );
    return null;
  }
}

/// What a step said while a check was running it.
///
/// Kept rather than printed: a step's own notes would otherwise land in the middle of a test run's
/// output and be read as its own.
final class CollectedLog implements Logger {
  /// Everything the step said, in order.
  final List<String> said = <String>[];

  @override
  void debug(String message) {
    said.add(message);
  }

  @override
  void info(String message) {
    said.add(message);
  }

  @override
  void warn(String message) {
    said.add(message);
  }

  @override
  void error(String message) {
    said.add(message);
  }
}

/// The context a check hands [step], carrying the ports it chose.
///
/// [Facts.none] because no predicate is evaluated here: a step that asks about one it did not have
/// evaluated throws, which is a defect in the step and is reported as such.
///
/// [publishes] is what the step's registry entry declares it measures, and [measurements] is where
/// those go. A step that measures does it inside its check, which is exactly what an audit runs — so
/// a context with nowhere to publish would turn every such step into a failure about the probe
/// rather than about the step. Passing a collection in is how a check reads what was published.
StepContext probeContext({
  required StepName step,
  required Arguments arguments,
  required Arguments answers,
  required Shell shell,
  required Files files,
  required Http http,
  required Clock clock,
  required Entropy entropy,
  required Logger log,
  List<MeasurementSpec> publishes = const <MeasurementSpec>[],
  Measurements? measurements,
}) => StepContext(
  shell: shell,
  files: files,
  http: http,
  clock: clock,
  entropy: entropy,
  log: log,
  step: step,
  arguments: arguments,
  answers: answers,
  // A collection of its own where the caller brought none, and it is handed a redactor that hides
  // NOTHING YET rather than the one that hides nothing ever: a spec declaring itself secret
  // registers its value at publish, and `Redactor.none` refuses to be registered with. A probe of a
  // step that publishes a secret would otherwise fail on the sentinel rather than on the step.
  measurements: (measurements ?? Measurements(Redactor(const <String>[]))).forStep(step, publishes),
  facts: Facts.none,
);

/// What a [CheckResult] answered, as one line, so two answers can be compared and reported.
String describeCheck(CheckResult result) => switch (result) {
  Ready() => 'ready',
  Satisfied(:final String because) => 'satisfied: $because',
  Blocked(:final String reason) => 'blocked: $reason',
};
