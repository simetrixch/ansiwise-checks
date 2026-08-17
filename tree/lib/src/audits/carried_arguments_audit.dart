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
/// WHAT IT STATES: how many files were read, how many argument reads were found, and how many
/// files-port calls in how many elevation-carrying files. A scan that found no read at all would
/// pass over any tree, and a scan that read no file looked nowhere — either would report a clean
/// tree while measuring nothing. The call count may honestly be zero: a tree in which no file
/// carries the elevation field has nothing for that half to judge, and the count says so out loud.
void auditCarriedArguments({required List<String> scannedPaths, SourceTree? tree}) {
  final SourceTree judged = tree ?? SourceTree.on(repositoryRoot());
  final CarriedArguments scan = CarriedArguments(tree: judged, scanned: scannedPaths);
  final List<String> carriers = scan.elevationCarriers;
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

  test('${scan.calls.length} files-port call(s) in ${carriers.length} file(s) carrying the '
      'elevation field were found to judge', () {
    if (carriers.isEmpty) {
      // Nothing here carries the field, so there is nothing this half can judge — a fact the
      // name of this test states rather than hides. That the shape is still recognised when it
      // appears is proven by the counter-probes below, not by this tree.
      expect(scan.calls, isEmpty);
      return;
    }
    expect(
      scan.calls,
      isNotEmpty,
      reason:
          'a file here carries the elevation field and no files-port call was seen beside it — '
          'either the call shape stopped matching, or this tree genuinely makes none and this '
          'expectation is wrong for it',
    );
  });

  test('every read is declared, and every carried elevation reaches every files-port call', () {
    expect(scan.findings, isEmpty, reason: scan.findings.join('; '));
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
  });
}
