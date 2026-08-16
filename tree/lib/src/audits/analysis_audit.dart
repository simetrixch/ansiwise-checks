/// The suite that starts the real analyzer and the real formatter over one package, with every
/// counter-probe that proves each half can go red.
library;

import 'dart:io';

import 'package:test/test.dart';

import '../analysis.dart';
import '../source_tree.dart';

/// Runs the analysis audit over the package this suite runs in, or over [directory].
///
/// WHAT IT STATES: how many files the formatter read, held against the Dart files of the tree —
/// a clean answer over a walk that stopped finding files is the one outcome a check must never
/// produce by accident, and the count against the tree is what rules it out.
///
/// The tools run once, at registration, and every assertion below reads that one answer: a second
/// run could answer differently about the same tree, and then the assertions would not be about
/// one reading.
void auditAnalysis({String? directory}) {
  final String judged = directory ?? repositoryRoot().path;
  final ToolAnswer analyzed = runDartTool(analyzerArgv, directory: judged);
  final ToolAnswer formatted = runDartTool(formatterArgv, directory: judged);
  final int dartFiles = SourceTree.on(Directory(judged)).dartFiles.length;
  final int? read = formatterFilesReadIn(formatted.output);

  test('the formatter read $read file(s), covering the $dartFiles Dart file(s) of this tree', () {
    expect(
      read,
      isNotNull,
      reason: 'the formatter wrote no summary, so nothing says how much a clean run covered',
    );
    expect(
      read,
      greaterThanOrEqualTo(dartFiles),
      reason:
          'the formatter read fewer files than this tree holds, so this check passed over source '
          'it claims to judge',
    );
  });

  test('dart analyze --fatal-infos --fatal-warnings is clean for this package', () {
    expect(analyzerIssuesIn(analyzed.output), isEmpty);
    expect(analyzed.exitCode, 0, reason: 'the analyzer did not answer green:\n${analyzed.output}');
  });

  test('dart format --output=none --set-exit-if-changed would change nothing', () {
    expect(
      formatterChangesIn(formatted.output),
      isEmpty,
      reason:
          'an unformatted file sits invisibly until an unrelated change picks it up, and then the '
          'diff is about the whitespace instead of the change',
    );
    expect(
      formatted.exitCode,
      0,
      reason: 'the formatter did not answer green:\n${formatted.output}',
    );
  });

  group('the invocation', () {
    // These two are about the argv rather than the answer, because weakening the invocation is
    // the one edit no output parser can notice: nothing is wrong with the OUTPUT of an analyzer
    // run that was never asked to be strict.

    test('the analyzer really is started with both flags', () {
      expect(analyzerArgv, containsAll(<String>['--fatal-infos', '--fatal-warnings']));
    });

    test('the formatter writes nothing and reports a difference', () {
      expect(
        formatterArgv,
        containsAll(<String>['--output=none', '--set-exit-if-changed']),
        reason:
            'a check that repaired what it measures would be green the second time for having '
            'changed the thing it judged',
      );
    });
  });

  group('reading the answers', () {
    // The rules that read the tools' output, held against the shape either tool writes. A rule
    // that stopped matching would read every run as clean, and the real-tools probes below would
    // not notice a parser that ignores what a red run wrote.

    test('the analyzer output is read one issue per line', () {
      expect(
        analyzerIssuesIn(
          'Analyzing planted...\n'
          '  error - lib/planted.dart:2:19 - A value of type String cannot be assigned - '
          'invalid_assignment\n'
          '   info - lib/planted.dart:3:3 - Unused import - unused_import\n'
          '2 issues found.\n',
        ),
        hasLength(2),
        reason: 'the analyzer writes a header and a count around its issues, and neither is one',
      );
    });

    test('a clean analyzer run reports nothing', () {
      expect(
        analyzerIssuesIn('Analyzing planted...\nNo issues found!\n'),
        isEmpty,
        reason: 'this rule reports every line, so it would turn every package red',
      );
    });

    test('the formatter output names the files it would change', () {
      expect(
        formatterChangesIn(
          'Changed lib/planted.dart\nFormatted 3 files (1 changed) in 0.04 seconds.\n',
        ),
        <String>['lib/planted.dart'],
        reason: 'the summary line is not a change, and the changed file is what a person opens',
      );
    });

    test('the count of files read comes off the summary line, singular and plural alike', () {
      expect(formatterFilesReadIn('Formatted 3 files (1 changed) in 0.04 seconds.\n'), 3);
      expect(formatterFilesReadIn('Formatted 1 file (0 changed) in 0.01 seconds.\n'), 1);
      expect(
        formatterFilesReadIn('nothing the formatter wrote\n'),
        isNull,
        reason: 'an answer with no summary must read as no denominator, never as zero covered',
      );
    });
  });

  group('counter-probe: the real tools go red on a planted fault', () {
    // The fault planted for the analyzer reports at INFO, not at error: an error is fatal under
    // any invocation, so a probe planting one stays green with `--fatal-infos` removed — and
    // removing it is exactly the edit that matters, because strict casts, strict inference and
    // strict raw types all report at info. The same tree is judged TWICE, with the flag and
    // without: "it went red" proves nothing until the weakened invocation is shown to go green on
    // the very same tree. And the clean tree beside them is what stops a check that refuses
    // everything from passing the probes above.

    late Directory onlyAnInfo;
    late Directory unformatted;
    late Directory clean;

    setUpAll(() {
      // One lint, enabled outright, so the planted package needs no dependency in order to
      // resolve. A lint reports at info, which is the level the shared strictness settings report
      // at.
      onlyAnInfo = _planted('info', <String, String>{
        'pubspec.yaml': 'name: planted_info\n',
        'analysis_options.yaml': 'linter:\n  rules:\n    - prefer_single_quotes\n',
        'lib/planted.dart': 'const String planted = "double";\n',
      });
      unformatted = _planted('unformatted', <String, String>{
        'pubspec.yaml': 'name: planted_unformatted\n',
        'lib/planted.dart': 'void main(){int   planted=1;print(planted);}\n',
      });
      clean = _planted('clean', <String, String>{
        'pubspec.yaml': 'name: planted_clean\n',
        'lib/planted.dart': 'void main() {\n  print(1);\n}\n',
      });
    });

    tearDownAll(() {
      onlyAnInfo.deleteSync(recursive: true);
      unformatted.deleteSync(recursive: true);
      clean.deleteSync(recursive: true);
    });

    test('a planted fault that only reports at info turns the analyzer red', () {
      final ToolAnswer answer = runDartTool(analyzerArgv, directory: onlyAnInfo.path);
      expect(
        analyzerIssuesIn(answer.output),
        isNotEmpty,
        reason: 'this check cannot go red on the analyzer, so its silence means nothing',
      );
      expect(answer.exitCode, isNot(0));
    });

    test('and the same tree passes once --fatal-infos is taken away', () {
      final ToolAnswer weakened = runDartTool(<String>[
        for (final String argument in analyzerArgv)
          if (argument != '--fatal-infos') argument,
      ], directory: onlyAnInfo.path);
      expect(
        weakened.exitCode,
        0,
        reason:
            'one flag fewer and the fault is gone from the verdict — which is why dropping it is '
            'a silent edit, and why only this pair of probes can catch it',
      );
    });

    test('a planted unformatted file turns the formatter red', () {
      final ToolAnswer answer = runDartTool(formatterArgv, directory: unformatted.path);
      expect(
        formatterChangesIn(answer.output),
        isNotEmpty,
        reason: 'this check cannot go red on the formatter, so its silence means nothing',
      );
      expect(answer.exitCode, isNot(0));
    });

    test('a clean tree is reported by neither tool', () {
      final ToolAnswer analyzedClean = runDartTool(analyzerArgv, directory: clean.path);
      final ToolAnswer formattedClean = runDartTool(formatterArgv, directory: clean.path);
      expect(
        analyzerIssuesIn(analyzedClean.output),
        isEmpty,
        reason: 'this check would turn every package red, so its red answers would mean nothing',
      );
      expect(analyzedClean.exitCode, 0);
      expect(formatterChangesIn(formattedClean.output), isEmpty);
      expect(formattedClean.exitCode, 0);
    });
  });
}

/// A scratch package a counter-probe writes: every key of [files] becomes a file under a fresh
/// directory in the system temp, holding that entry's text.
Directory _planted(String name, Map<String, String> files) {
  final Directory directory = Directory.systemTemp.createTempSync('ansiwise-analysis-$name-');
  for (final MapEntry<String, String> entry in files.entries) {
    File('${directory.path}/${entry.key}')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(entry.value);
  }
  return directory;
}
