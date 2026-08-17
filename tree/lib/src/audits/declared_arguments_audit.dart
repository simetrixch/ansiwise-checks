/// The suite that drives the declared-argument scan over one tree, with its counter-probes.
library;

import 'package:test/test.dart';

import '../declared_arguments.dart';
import '../finding.dart';
import '../source_tree.dart';

/// Runs the declared-argument audit over [tree], or over the repository this suite sits in.
///
/// [scannedPaths] are the directories read, named one at a time by the caller rather than derived,
/// so widening the scan is a decision somebody makes rather than a silent change.
///
/// WHAT IT STATES: how many arguments were found declared and how many files were read. A scan that
/// found no declaration at all would pass over any tree, and a scan that read no file looked nowhere
/// — either would report a clean tree while measuring nothing.
void auditDeclaredArguments({required List<String> scannedPaths, SourceTree? tree}) {
  final SourceTree judged = tree ?? SourceTree.on(repositoryRoot());
  final DeclaredArguments scan = DeclaredArguments(tree: judged, scanned: scannedPaths);
  final String where = scannedPaths.join(', ');

  test('${scan.files.length} file(s) under $where were read', () {
    expect(scan.files, isNotEmpty, reason: 'none of $where is in this tree');
  });

  test('${scan.declared.length} declared argument(s) were found to judge', () {
    expect(
      scan.declared,
      isNotEmpty,
      reason:
          'a scan that finds no declaration passes over any tree at all, so an empty answer here '
          'means the scan did not recognise the shape rather than that the tree is clean',
    );
  });

  test('every argument a file declares is read by that file', () {
    expect(scan.findings, isEmpty, reason: scan.findings.join('; '));
  });

  group('counter-probe', () {
    // THE TWO SHAPES THIS CATCHES, both of which happened in one day.
    test('an argument declared and never read is reported', () {
      const String planted = '''
final class Subject {
  factory Subject.fromArguments(Arguments arguments) => Subject(one: arguments.text('one'));
  static const List<ArgumentSpec> arguments = <ArgumentSpec>[
    ArgumentSpec(name: 'one', kind: ArgumentKind.text, describes: 'the one that is read'),
    ArgumentSpec(name: 'two', kind: ArgumentKind.flag, describes: 'the one nothing reads'),
  ];
}
''';

      final List<Finding> found = DeclaredArguments.findingsIn(planted, 'lib/subject.dart');

      expect(found, hasLength(1));
      expect(found.single.what, contains('"two"'));
    });

    test('an argument declared under one name and read under another is reported', () {
      // The exact shape found on 2026-08-17: the plural declared, the singular read. The argument
      // check passed, because the name WAS declared, and nothing ever looked it up.
      const String planted = '''
final class Subject {
  factory Subject.fromArguments(Arguments arguments) =>
      Subject(only: arguments.optionalText('skippable_answer'));
  static const List<ArgumentSpec> arguments = <ArgumentSpec>[
    ArgumentSpec(name: 'skippable_answers', kind: ArgumentKind.textList, describes: 'a list'),
  ];
}
''';

      final List<Finding> found = DeclaredArguments.findingsIn(planted, 'lib/subject.dart');

      expect(found, hasLength(1));
      expect(found.single.what, contains('"skippable_answers"'));
    });

    test('THE INNOCENT NEIGHBOUR: an argument that IS read is not reported', () {
      // Without this a scan that reported every declaration would pass all three assertions above,
      // and a clean answer would mean nothing.
      const String planted = '''
final class Subject {
  factory Subject.fromArguments(Arguments arguments) => Subject(one: arguments.text('one'));
  static const List<ArgumentSpec> arguments = <ArgumentSpec>[
    ArgumentSpec(name: 'one', kind: ArgumentKind.text, describes: 'the one that is read'),
  ];
}
''';

      expect(DeclaredArguments.findingsIn(planted, 'lib/subject.dart'), isEmpty);
    });

    test('a spec whose describes runs over several lines is still read as one', () {
      // The ordinary shape in this tree, and the one a pattern-based scan gets wrong: the name and
      // the closing bracket are lines apart, with brackets of the description in between.
      const String planted = '''
final class Subject {
  factory Subject.fromArguments(Arguments arguments) => Subject(one: arguments.text('one'));
  static const List<ArgumentSpec> arguments = <ArgumentSpec>[
    ArgumentSpec(
      name: 'one',
      kind: ArgumentKind.text,
      describes:
          'something long enough to wrap, with (brackets) in it, and a second '
          'line after that',
    ),
  ];
}
''';

      expect(DeclaredArguments.findingsIn(planted, 'lib/subject.dart'), isEmpty);
      expect(argumentsDeclaredIn(planted, 'lib/subject.dart'), hasLength(1));
    });

    test('a name mentioned ONLY inside the declaration does not count as read', () {
      // The loophole worth closing on purpose: the description of an argument usually repeats its
      // own name, so a scan searching the whole file would call every declaration read.
      const String planted = '''
final class Subject {
  factory Subject.fromArguments(Arguments arguments) => const Subject();
  static const List<ArgumentSpec> arguments = <ArgumentSpec>[
    ArgumentSpec(
      name: 'two',
      kind: ArgumentKind.flag,
      describes: "whether 'two' is set, which nothing here looks up",
    ),
  ];
}
''';

      expect(DeclaredArguments.findingsIn(planted, 'lib/subject.dart'), hasLength(1));
    });

    test('a SHARED declaration is judged against the whole scan, not its own file', () {
      // The blind spot found by running it: a file whose whole job is to declare arguments several
      // steps put in their own lists. It never reads them, and it is not meant to.
      const String declares = """
const ArgumentSpec statusCommandArgument = ArgumentSpec(
  name: 'status_command',
  kind: ArgumentKind.textList,
  describes: 'how the addons are asked',
);
""";
      const String reads = "statusCommand: arguments.textList('status_command'),";

      expect(DeclaredArguments.findingsIn(declares, 'lib/a.dart', alsoRead: reads), isEmpty);
    });

    test('and a shared one nothing anywhere reads is STILL reported', () {
      // Without this the widening would swallow the check for every named declaration.
      const String declares = """
const ArgumentSpec orphan = ArgumentSpec(
  name: 'nobody_reads_this',
  kind: ArgumentKind.flag,
  describes: 'nothing at all',
);
""";

      final List<Finding> found = DeclaredArguments.findingsIn(
        declares,
        'lib/a.dart',
        alsoRead: "something: arguments.text('unrelated'),",
      );

      expect(found, hasLength(1));
      expect(found.single.what, contains('nobody_reads_this'));
    });

    test('an INLINE one is not saved by another file reading the same word', () {
      // The other direction, and the reason the two are told apart at all: a misspelled argument in
      // one step must not pass because a different step happens to use that word correctly.
      const String planted = """
final class Subject {
  factory Subject.fromArguments(Arguments arguments) => const Subject();
  static const List<ArgumentSpec> arguments = <ArgumentSpec>[
    ArgumentSpec(name: 'two', kind: ArgumentKind.flag, describes: 'nothing here reads it'),
  ];
}
""";

      expect(
        DeclaredArguments.findingsIn(planted, 'lib/a.dart', alsoRead: "arguments.flag('two')"),
        hasLength(1),
      );
    });
  });
}
