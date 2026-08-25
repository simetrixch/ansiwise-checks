/// The suite that drives the carried-argument scan over one tree, with its counter-probes.
library;

import 'package:test/test.dart';

import '../carried_arguments.dart';
import '../finding.dart';
import '../source_tree.dart';

/// Runs the carried-argument audit over [tree], or over the repository this suite sits in.
///
/// [scannedPaths] are the directories read, named one at a time by the caller rather than derived,
/// so widening the scan is a decision somebody makes rather than a silent change.
///
/// WHAT IT STATES: how many files were read, how many argument reads were found, and how many calls
/// of EACH PORT in how many elevation-carrying files. A scan that found no read at all would pass
/// over any tree, and a scan that read no file looked nowhere — either would report a clean tree
/// while measuring nothing.
///
/// **The two port counts are stated separately because one of them was zero for as long as the scan
/// existed.** The second hop judged the files port alone, so every command a step composed went
/// unjudged while the run printed a clean tree — and a summed count would have shown a large,
/// reassuring number the whole time. Either may honestly be zero: a tree whose steps only write
/// files composes no command, and a tree in which nothing carries the elevation at all has nothing
/// for this half. What matters is that the number is on the screen rather than inside a sum.
///
/// **The file count says CARRYING THE ELEVATION and means a field or a parameter.** It counted
/// field-carrying files alone for a while, and a summary read off it therefore described the
/// coverage of a scan that was looking at less — which is the failure this audit exists to refuse,
/// one level up. The number here and the sentence the library doc writes about it move together.
///
/// **NEITHER COUNT HAS A FLOOR, and the port-call test asserts none.** A tree whose steps only
/// write files composes no command; a tree in which nothing carries the elevation has nothing for
/// this half at all; and a file that takes the elevation to hand it to another helper carries it
/// without reaching a port itself, so it is counted among the carriers with no call under it. A
/// check demanding a call beside every carrier goes red on a tree that is clean and states a
/// reason that is not true of it, which is the one thing a check may never do. What the two
/// numbers are held to instead is that they are read off the SAME population, and that the shapes
/// are still recognised at all is proven by the counter-probes on planted text rather than by
/// whatever the tree in front of them happens to hold.
void auditCarriedArguments({required List<String> scannedPaths, SourceTree? tree}) {
  final SourceTree judged = tree ?? SourceTree.on(repositoryRoot());
  final CarriedArguments scan = CarriedArguments(tree: judged, scanned: scannedPaths);
  final List<String> carriers = scan.elevationCarriers;
  final List<PortCall> filesPortCalls = scan.filesPortCalls;
  final List<PortCall> commands = scan.commandCalls;
  final List<Finding> findings = scan.findings;
  final String where = scannedPaths.join(', ');

  test('${scan.files.length} file(s) under $where were read', () {
    expect(scan.files, isNotEmpty, reason: 'none of $where is in this tree');
  });

  test('${scan.reads.length} argument read(s) were found to judge', () {
    expect(
      scan.reads,
      isNotEmpty,
      reason:
          'a scan that finds no read passes over any tree at all, so an empty answer here means '
          'the scan did not recognise the shape rather than that the tree is clean',
    );
  });

  test('${filesPortCalls.length} files-port call(s) and ${commands.length} command(s) composed in '
      '${carriers.length} file(s) carrying the elevation in a field or in a parameter were found '
      'to judge', () {
    expect(
      <String>{
        for (final PortCall call in <PortCall>[...filesPortCalls, ...commands]) call.path,
      }.difference(carriers.toSet()),
      isEmpty,
      reason:
          'a call was judged in a file this same scan does not count as carrying the elevation, so '
          'the two numbers above are measured over different populations — and a number read off '
          'the narrower one is how a summary came to describe a wider coverage than the scan had',
    );
  });

  test('every read is declared, and every carried elevation reaches every call', () {
    expect(findings, isEmpty, reason: findings.join('; '));
  });

  group('counter-probe', () {
    // THE FIRST HOP: a read of an argument the file never declares.
    test('a read of an argument the file never declares is reported', () {
      const String planted = '''
final class Subject {
  factory Subject.fromArguments(Arguments arguments) =>
      Subject(one: arguments.text('one'), two: arguments.flag('two'));
  static const List<ArgumentSpec> arguments = <ArgumentSpec>[
    ArgumentSpec(name: 'one', kind: ArgumentKind.text, describes: 'the declared one'),
  ];
}
''';

      final List<Finding> found = CarriedArguments.findingsIn(planted, 'lib/subject.dart');

      expect(found, hasLength(1));
      expect(found.single.what, contains('"two"'));
    });

    test('a different argument whose constant merely ends the same is no declaration', () {
      // The exact shape found on 2026-08-17, eight times: the list carries the CLASS's own
      // elevation spec, which declares a different name, and only a substring comparison would
      // read it as a declaration of "elevated". Qualified, the identifier names that class's
      // constant and nothing else.
      const String planted = '''
final class Subject {
  factory Subject.fromArguments(Arguments arguments) => Subject(
    client: Client.fromArguments(arguments),
    elevated: arguments.has('elevated') && arguments.flag('elevated'),
  );
  static const List<ArgumentSpec> arguments = <ArgumentSpec>[
    Client.argument,
    Client.elevationArgument,
  ];
}
''';

      final List<Finding> found = CarriedArguments.findingsIn(planted, 'lib/subject.dart');

      expect(found, hasLength(1));
      expect(found.single.what, contains('"elevated"'));
    });

    test('THE INNOCENT NEIGHBOUR: the shared identifier standing bare is a declaration', () {
      // The fixed state of the eight: the framework's own spec put in the list beside the
      // class's. Without this a scan that reported every read of "elevated" would pass the two
      // probes above, and a clean answer would mean nothing.
      const String planted = '''
final class Subject {
  factory Subject.fromArguments(Arguments arguments) => Subject(
    client: Client.fromArguments(arguments),
    elevated: arguments.has('elevated') && arguments.flag('elevated'),
  );
  static const List<ArgumentSpec> arguments = <ArgumentSpec>[
    Client.argument,
    Client.elevationArgument,
    elevationArgument,
  ];
}
''';

      expect(CarriedArguments.findingsIn(planted, 'lib/subject.dart'), isEmpty);
    });

    test('declaring a static spec under the shared identifier is not using the shared one', () {
      // The declaration site writes the identifier bare, followed by `=`. Counting that as a use
      // would let the one file that DECLARES a same-named class spec read "elevated" undeclared.
      const String planted = '''
final class Client {
  factory Client.fromArguments(Arguments arguments) => Client(
    elevated: arguments.has('elevated') && arguments.flag('elevated'),
    needsRoot: arguments.flag('client_needs_root'),
  );

  static const ArgumentSpec elevationArgument = ArgumentSpec(
    name: 'client_needs_root',
    kind: ArgumentKind.flag,
    describes: 'whether the client is invoked as root',
  );
}
''';

      final List<Finding> found = CarriedArguments.findingsIn(planted, 'lib/client.dart');

      expect(found, hasLength(1));
      expect(found.single.what, contains('"elevated"'));
    });

    test('a shared spec declared in another file covers the read that lists its identifier', () {
      // The shape a package's own shared specs have: declared once, put in several steps' lists.
      // Resolving them takes the whole scan, which is why the map is built over every file.
      final SourceTree planted = SourceTree.planted(<String, String?>{
        'lib/render_command.dart': '''
const ArgumentSpec renderCommandArgument = ArgumentSpec(
  name: 'render_command',
  kind: ArgumentKind.textList,
  describes: 'how a template is rendered',
);
''',
        'lib/render_step.dart': '''
final class Subject {
  factory Subject.fromArguments(Arguments arguments) =>
      Subject(command: arguments.textList('render_command'));
  static const List<ArgumentSpec> arguments = <ArgumentSpec>[renderCommandArgument];
}
''',
      });

      final CarriedArguments scan = CarriedArguments(tree: planted, scanned: const <String>['lib']);

      expect(scan.findings, isEmpty);
    });

    test('and a file that never names the identifier is not saved by the rest of the scan', () {
      // The other direction: the spec existing SOMEWHERE must not cover a step that forgot to put
      // it in its list — that step still never receives the value.
      final SourceTree planted = SourceTree.planted(<String, String?>{
        'lib/render_command.dart': '''
const ArgumentSpec renderCommandArgument = ArgumentSpec(
  name: 'render_command',
  kind: ArgumentKind.textList,
  describes: 'how a template is rendered',
);
''',
        'lib/render_step.dart': '''
final class Subject {
  factory Subject.fromArguments(Arguments arguments) =>
      Subject(command: arguments.textList('render_command'));
  static const List<ArgumentSpec> arguments = <ArgumentSpec>[];
}
''',
      });

      final List<Finding> found = CarriedArguments(
        tree: planted,
        scanned: const <String>['lib'],
      ).findings;

      expect(found, hasLength(1));
      expect(found.single.subject, 'lib/render_step.dart');
      expect(found.single.what, contains('"render_command"'));
    });

    test('a static spec in one file does not take the shared identifier over for the scan', () {
      // If the map builder read statics, the class spec would REPLACE the framework's entry for
      // the whole scan, and every correctly fixed file would be reported for a read the bare
      // identifier really does declare.
      final SourceTree planted = SourceTree.planted(<String, String?>{
        'lib/client.dart': '''
final class Client {
  static const ArgumentSpec elevationArgument = ArgumentSpec(
    name: 'client_needs_root',
    kind: ArgumentKind.flag,
    describes: 'whether the client is invoked as root',
  );
}
''',
        'lib/subject.dart': '''
final class Subject {
  factory Subject.fromArguments(Arguments arguments) =>
      Subject(elevated: arguments.has('elevated') && arguments.flag('elevated'));
  static const List<ArgumentSpec> arguments = <ArgumentSpec>[elevationArgument];
}
''',
      });

      final CarriedArguments scan = CarriedArguments(tree: planted, scanned: const <String>['lib']);

      expect(scan.findings, isEmpty);
    });

    // THE SECOND HOP: a carried elevation dropped at one files-port call.
    test('a call over several lines with brackets in its arguments is read whole and reported', () {
      // The exact shape found on 2026-08-17, four times: the call the row is obviously about
      // carried the elevation, and one written beside it did not. A pattern per line cannot read
      // this — the call's own closing bracket is lines away, behind brackets of its arguments.
      const String planted = '''
final class Subject {
  const Subject({required this.elevated});

  final bool elevated;

  Future<void> apply(StepContext context) async {
    await context.files.write(
      path,
      hostsToml(mirrorHost(host), blob),
      mode: fileMode,
    );
  }
}
''';

      final List<Finding> found = CarriedArguments.findingsIn(planted, 'lib/subject.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 7);
      expect(found.single.what, contains('write'));
    });

    test('an inner call that passes the elevation does not cover the outer one', () {
      // The word has to stand among the call's OWN arguments. Inside a nested call it elevates
      // that call, and the outer one still acts as the operator.
      const String planted = '''
final class Subject {
  final bool elevated;

  Future<void> apply(StepContext context) async {
    await context.files.write(path, composed(elevated: elevated), mode: fileMode);
  }
}
''';

      expect(CarriedArguments.findingsIn(planted, 'lib/subject.dart'), hasLength(1));
    });

    test('THE INNOCENT NEIGHBOUR: a call that passes the elevation on is not reported', () {
      const String planted = '''
final class Subject {
  final bool elevated;

  Future<void> apply(StepContext context) async {
    if (!await context.files.exists(path, elevated: elevated)) {
      return;
    }
    await context.files.write(
      path,
      hostsToml(mirrorHost(host), blob),
      mode: fileMode,
      elevated: elevated,
    );
  }
}
''';

      expect(CarriedArguments.findingsIn(planted, 'lib/subject.dart'), isEmpty);
    });

    test('a file that never carries the elevation field owes it to no call', () {
      // Half of what a step touches is plainly the operator's, and a step that never declares the
      // elevation makes its calls without it by design.
      const String planted = '''
final class Subject {
  Future<void> apply(StepContext context) async {
    await context.files.delete(path);
  }
}
''';

      expect(CarriedArguments.findingsIn(planted, 'lib/subject.dart'), isEmpty);
    });

    // THE SECOND HOP THROUGH THE OTHER PORT: a carried elevation dropped where a command is
    // composed. The files port was the only one judged for as long as this scan existed.
    test('a command composed without the elevation the file carries is reported', () {
      // The exact shape found on 2026-08-24: the step asked the cluster for its credentials as the
      // account the run started as, on a machine that had put that account into the group granting
      // access one step earlier. Supplementary groups are read once, when a session starts, so the
      // command was refused and the same program passed on its second run.
      const String planted = '''
final class Subject {
  const Subject({required this.credentialsCommand, this.elevated = false});

  final List<String> credentialsCommand;

  final bool elevated;

  Future<CommandResult> ask(StepContext context) => context.shell.run(
    Command.observing(
      credentialsCommand.first,
      arguments: credentialsCommand.sublist(1),
    ),
  );
}
''';

      final List<Finding> found = CarriedArguments.findingsIn(planted, 'lib/subject.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 9);
      expect(found.single.what, contains('Command.observing'));
    });

    test('THE INNOCENT NEIGHBOUR: a command that carries the elevation is not reported', () {
      const String planted = '''
final class Subject {
  final bool elevated;

  Future<CommandResult> ask(StepContext context) => context.shell.run(
    Command.observing(
      credentialsCommand.first,
      arguments: credentialsCommand.sublist(1),
      elevated: elevated,
    ),
  );
}
''';

      expect(CarriedArguments.findingsIn(planted, 'lib/subject.dart'), isEmpty);
    });

    test('an answer written out is an answer: elevated: true carries it', () {
      // The chown that hands a directory to an account is elevated whatever the row said about the
      // file it wrote, and a scan wanting the FIELD by name would report the one call in the tree
      // that decided the question on purpose.
      const String planted = '''
final class Subject {
  final bool elevated;

  Future<void> hand(StepContext context) async {
    await context.shell.run(
      Command.detailed('chown', arguments: <String>['-R', owner, directory], elevated: true),
    );
  }
}
''';

      expect(CarriedArguments.findingsIn(planted, 'lib/subject.dart'), isEmpty);
    });

    test('the plain constructor cannot carry it, so composing with it is reported', () {
      // `Command(executable, arguments)` takes no elevation and fixes it to false, so a file that
      // carries an elevation and reaches the machine through it has dropped the row's answer by
      // choosing that constructor.
      const String planted = '''
final class Subject {
  final bool elevated;

  Future<void> apply(StepContext context) async {
    await context.shell.run(const Command('systemctl', <String>['daemon-reload']));
  }
}
''';

      final List<Finding> found = CarriedArguments.findingsIn(planted, 'lib/subject.dart');

      expect(found, hasLength(1));
      expect(found.single.what, contains('Command call'));
    });

    test('a command composed in one method and run in another is still judged', () {
      // Where the command is COMPOSED is what carries the elevation; `context.shell.run` only hands
      // on what the command already says. A scan reading run's own arguments would see the
      // elevation nowhere and report every step in the tree, and one reading the whole call would
      // take an inner value for the outer call's answer.
      const String planted = '''
final class Subject {
  final bool elevated;

  Command _observe(List<String> arguments) =>
      Command.detailed('git', arguments: arguments, observes: true);

  Future<CommandResult> ask(StepContext context) => context.shell.run(_observe(argv));
}
''';

      final List<Finding> found = CarriedArguments.findingsIn(planted, 'lib/subject.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 5);
    });

    test('a command in a file that carries no elevation owes it to nobody', () {
      const String planted = '''
final class Subject {
  Future<void> apply(StepContext context) async {
    await context.shell.run(const Command('systemctl', <String>['daemon-reload']));
  }
}
''';

      expect(CarriedArguments.findingsIn(planted, 'lib/subject.dart'), isEmpty);
    });

    test('a result and a failure named after a command are neither of them one', () {
      // `CommandResult` and `CommandFailed` begin with the same word, and a scan matching the word
      // rather than the constructor would report the two places every step reads what a command
      // did.
      const String planted = '''
final class Subject {
  final bool elevated;

  Future<void> apply(StepContext context) async {
    final CommandResult answer = await context.shell.run(
      Command.detailed('git', arguments: argv, elevated: elevated),
    );
    if (!answer.ok) {
      throw CommandFailed(argv: argv, exitCode: answer.exitCode, stdout: '', stderr: '');
    }
  }
}
''';

      expect(CarriedArguments.findingsIn(planted, 'lib/subject.dart'), isEmpty);
    });

    // THE SECOND HOP WHERE THE ELEVATION STANDS IN A PARAMETER. A step hands the row's answer to a
    // helper of its own, and the helper's file writes the field nowhere — so a gate on the field
    // text judged no call in such a file at all, through either port.
    test('a files-port call in a function taking the elevation drops it and is reported', () {
      // The shape a helper reading a file for its caller has: the elevation is required, so the
      // caller cannot leave it out, and one of the two calls beside it still does not pass it on.
      const String planted = '''
Future<String?> recordedValue(
  StepContext context,
  String file,
  String key, {
  required bool elevated,
}) async {
  if (!await context.files.exists(file)) {
    return null;
  }
  final String content = await context.files.read(file, elevated: elevated);
  return valueIn(content, key);
}
''';

      final List<Finding> found = CarriedArguments.findingsIn(planted, 'lib/recorded_value.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 7);
      expect(found.single.what, contains('exists'));
    });

    test('THE INNOCENT NEIGHBOUR: a function that passes its own elevation on is not reported', () {
      const String planted = '''
Future<String?> recordedValue(
  StepContext context,
  String file,
  String key, {
  required bool elevated,
}) async {
  if (!await context.files.exists(file, elevated: elevated)) {
    return null;
  }
  final String content = await context.files.read(file, elevated: elevated);
  return valueIn(content, key);
}
''';

      expect(CarriedArguments.findingsIn(planted, 'lib/recorded_value.dart'), isEmpty);
    });

    test('a command composed in a function taking the elevation drops it and is reported', () {
      // The exact residue proven blind on 2026-08-25: a command composed by a helper, in a file
      // that carries no field, with the row's answer standing in the helper's own parameter. The
      // scan that judged files by the field text reported nothing here.
      const String planted = '''
Future<CommandResult> ask(
  StepContext context,
  List<String> statusCommand, {
  bool elevated = false,
}) async {
  return context.shell.run(
    Command.observing(statusCommand.first, arguments: statusCommand.sublist(1)),
  );
}
''';

      final List<Finding> found = CarriedArguments.findingsIn(planted, 'lib/status.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 7);
      expect(found.single.what, contains('Command.observing'));
    });

    test('an arrow body is the region an arrow function carries its elevation over', () {
      // The other of the two body shapes. A gate that read only block bodies would judge nothing
      // in a helper written as one expression, which is how the shortest of them are written.
      const String planted = '''
Future<bool> present(StepContext context, String path, {required bool elevated}) =>
    context.files.exists(path);
''';

      final List<Finding> found = CarriedArguments.findingsIn(planted, 'lib/present.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 2);
    });

    test('THE INNOCENT NEIGHBOUR: the function beside it has no elevation to pass', () {
      // WHY THE REGION IS THE BODY AND NOT THE FILE. One function takes the elevation and the one
      // above it does not, and the call in the second has nothing to pass on — reporting it would
      // name a place whose only fix is to add a parameter nobody asked for, and a scan that does
      // that gets read once and then stops being read.
      const String planted = '''
Future<void> writeAsOperator(StepContext context, String path, String text) async {
  await context.files.write(path, text);
}

Future<void> writeAsRow(
  StepContext context,
  String path,
  String text, {
  required bool elevated,
}) async {
  await context.files.write(path, text);
}
''';

      final List<Finding> found = CarriedArguments.findingsIn(planted, 'lib/writes.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 11);
    });

    test('a parameter on a declaration with no body carries the elevation nowhere', () {
      // An interface names the parameter and makes no call, so it opens nothing: without this the
      // one file declaring the port surface would put every call in the file under the scan.
      const String planted = '''
abstract interface class FilesPort {
  Future<bool> exists(String path, {required bool elevated});
}

Future<void> apply(StepContext context, String path) async {
  await context.files.delete(path);
}
''';

      expect(CarriedArguments.findingsIn(planted, 'lib/files_port.dart'), isEmpty);
    });

    test('a function taking the elevation and reaching no port is a carrier with no call', () {
      // WHY THE PORT-CALL TEST ABOVE ASSERTS NO FLOOR. This helper carries the elevation and hands
      // it on without touching a port of its own, so it is honestly counted among the carriers
      // with nothing under it. Six of the twelve packages this audit runs in reach no files port
      // and compose no command at all, and one helper of this shape is all it takes to put one of
      // them into this state.
      final SourceTree planted = SourceTree.planted(<String, String?>{
        'lib/request.dart': '''
Future<HttpResponse> request(
  StepContext context,
  String endpoint, {
  required bool elevated,
}) async {
  return context.http.get(endpoint, elevated: elevated);
}
''',
      });

      final CarriedArguments scan = CarriedArguments(tree: planted, scanned: const <String>['lib']);

      expect(scan.elevationCarriers, hasLength(1));
      expect(scan.calls, isEmpty);
      expect(scan.findings, isEmpty);
    });

    test('a constructor is judged over its body, past the initializer list before it', () {
      // A parameter list followed by `: field = value` is not a declaration without a body. Read as
      // one it opens no region, so every call the constructor makes goes unjudged.
      const String planted = '''
final class Subject {
  Subject(StepContext context, {required bool elevated})
    : _context = context,
      _elevated = elevated {
    _command = Command.detailed('git', arguments: <String>['status']);
  }

  final StepContext _context;

  final bool _elevated;

  late final Command _command;
}
''';

      final List<Finding> found = CarriedArguments.findingsIn(planted, 'lib/subject.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 5);
      expect(found.single.what, contains('Command.detailed'));
    });

    test('a collection literal in an initializer list is not the body', () {
      // `const <String, String>{}` opens a brace at the same depth the body does, and what tells
      // the two apart is what FOLLOWS the matching brace: an initializer list goes on, and after a
      // body nothing of the declaration is left. Taking the literal for the body would end the
      // region at its closing brace and leave the real body unjudged.
      const String planted = '''
final class Subject {
  Subject(StepContext context, {required bool elevated})
    : _labels = const <String, String>{},
      _context = context {
    _command = Command.detailed('git', arguments: <String>['status']);
  }

  final Map<String, String> _labels;

  final StepContext _context;

  late final Command _command;
}
''';

      final List<Finding> found = CarriedArguments.findingsIn(planted, 'lib/subject.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 5);
    });

    test('THE INNOCENT NEIGHBOUR: a constructor that passes its elevation on is not reported', () {
      const String planted = '''
final class Subject {
  Subject(StepContext context, {required bool elevated})
    : _context = context,
      _elevated = elevated {
    _command = Command.detailed('git', arguments: <String>['status'], elevated: elevated);
  }

  final StepContext _context;

  final bool _elevated;

  late final Command _command;
}
''';

      expect(CarriedArguments.findingsIn(planted, 'lib/subject.dart'), isEmpty);
    });

    // A REGION IS FOUND BY COUNTING BRACES, and a comment or a string carries braces that open
    // nothing. Each of the five below reported the wrong thing while the count was taken over the
    // file as written rather than over `codeOf`.
    test('a signature quoted in a doc comment opens no region and carries no elevation', () {
      // The brace of the quoted signature opened a region running into the function below, and the
      // call there — which has no elevation to pass — was reported. The only fix a reader could
      // see was to delete the comment.
      const String planted = '''
/// Writes the file as the account the run started as.
///
/// The elevated form is `Future<void> apply(StepContext c, {required bool elevated}) async {`
Future<void> writeAsOperator(StepContext context, String path, String text) async {
  await context.files.write(path, text);
}
''';

      final SourceTree tree = SourceTree.planted(<String, String?>{'lib/writes.dart': planted});
      final CarriedArguments scan = CarriedArguments(tree: tree, scanned: const <String>['lib']);

      expect(scan.elevationCarriers, isEmpty);
      expect(scan.findings, isEmpty);
    });

    test('an unmatched opening brace in a string keeps the region inside its own body', () {
      // A template, a shell fragment or a `RegExp` carries a brace that opens nothing. Counting it
      // ran the region past the closing brace of the elevated body and swallowed the function
      // written beside it, whose own call has nothing to pass.
      const String planted = r'''
Future<void> writeTemplate(
  StepContext context,
  String path,
  String template, {
  required bool elevated,
}) async {
  final String body = template.replaceAll(RegExp(r'\{'), '');
  await context.files.write(path, body);
}

Future<void> writeAsOperator(StepContext context, String path, String text) async {
  await context.files.write(path, text);
}
''';

      final List<Finding> found = CarriedArguments.findingsIn(planted, 'lib/template.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 8);
    });

    test('an unmatched closing brace in a string does not end the region early', () {
      // The mirror, and the worse of the two: the region ended at the brace inside the string, so
      // the call that really drops the elevation was never judged — while the file went on being
      // counted among the files this scan judged. Nothing is on the screen but a number that means
      // less than it says.
      const String planted = r'''
Future<void> writeTemplate(
  StepContext context,
  String path,
  String template, {
  required bool elevated,
}) async {
  final String body = template.replaceAll(RegExp(r'\}'), '');
  await context.files.write(path, body);
}
''';

      final SourceTree tree = SourceTree.planted(<String, String?>{'lib/template.dart': planted});
      final CarriedArguments scan = CarriedArguments(tree: tree, scanned: const <String>['lib']);

      expect(scan.elevationCarriers, hasLength(1));
      expect(scan.calls, hasLength(1));
      expect(scan.findings, hasLength(1));
      expect(scan.findings.single.line, 8);
    });

    test('a closing bracket in a string argument does not end the call before its elevation', () {
      // The same counting one level in: the bracket inside the shell fragment closed the call
      // early, so the elevation standing after it was outside the call's own arguments and a call
      // that passes it was reported.
      const String planted = '''
final class Subject {
  final bool elevated;

  Future<void> apply(StepContext context) async {
    await context.shell.run(
      Command.detailed('sh', arguments: <String>['-c', 'echo )'], elevated: elevated),
    );
  }
}
''';

      expect(CarriedArguments.findingsIn(planted, 'lib/subject.dart'), isEmpty);
    });

    test('an opening bracket in a string argument takes no later word for this call answer', () {
      // Its mirror, and the silent one: the bracket inside the fragment kept the call open past
      // its own closing bracket, so the `elevated` written on the next line counted as this call's
      // answer and a real drop was reported nowhere.
      const String planted = '''
final class Subject {
  final bool elevated;

  Future<void> apply(StepContext context) async {
    await context.files.write(path, 'echo (');
    final String mode = elevated ? 'row' : 'operator';
    await context.files.write(other, mode, elevated: elevated);
  }
}
''';

      final List<Finding> found = CarriedArguments.findingsIn(planted, 'lib/subject.dart');

      expect(found, hasLength(1));
      expect(found.single.line, 5);
    });
  });
}
