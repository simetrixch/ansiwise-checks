/// The analyzer and the formatter, started over one package's own tree, and the reading of what
/// they answered.
///
/// Every package answers `dart analyze` and `dart format` from its own suite, the way it answers
/// its other checks: a gate walks the packages of the repository the gate lives in, so a package
/// in any other repository is walked by no gate at all, and its whitespace debt sits invisibly
/// until an unrelated change picks it up.
///
/// What is here is the invocations and the reading of their answers; the suite that drives them
/// and plants the counter-probes is the audit next door.
library;

import 'dart:io';

/// How the analyzer is started, and why the flags are a value rather than a literal.
///
/// `--fatal-infos` is not a preference. The shared rule set turns on strict casts, strict
/// inference and strict raw types, and every one of them reports at INFO — so a run without the
/// flag reports success over exactly the fault class those settings exist to catch. Named so a
/// counter-probe can judge one planted tree twice, with the flag and without: "it went red"
/// proves nothing until the weakened invocation is shown to go green on the very same tree.
const List<String> analyzerArgv = <String>['analyze', '--fatal-infos', '--fatal-warnings'];

/// How the formatter is started.
///
/// `--output=none` so a red run leaves the tree exactly as it found it: a check that repaired
/// what it measures would be green the second time for having changed the thing it judged.
const List<String> formatterArgv = <String>[
  'format',
  '--output=none',
  '--set-exit-if-changed',
  '.',
];

/// What one tool answered: its exit code, and everything it wrote on both streams.
final class ToolAnswer {
  /// Records the answer of one run.
  const ToolAnswer({required this.exitCode, required this.output});

  /// What the tool exited with.
  final int exitCode;

  /// What it wrote, stdout and stderr in one text.
  final String output;
}

/// Starts this process's own `dart` with [arguments], from inside [directory].
///
/// [Platform.resolvedExecutable] rather than the word `dart` on the PATH, so the tool that judges
/// the code is the same one that compiled the judge — a machine carrying two SDKs cannot analyse
/// the tree with one and report under the name of the other. Every call runs FROM inside the
/// package rather than naming it as an argument, so the analysis_options that applies is the one
/// that package ships.
ToolAnswer runDartTool(List<String> arguments, {required String directory}) {
  final ProcessResult result = Process.runSync(
    Platform.resolvedExecutable,
    arguments,
    workingDirectory: directory,
    runInShell: false,
  );
  return ToolAnswer(exitCode: result.exitCode, output: '${result.stdout}${result.stderr}');
}

/// Every issue in what the analyzer wrote, one per line.
///
/// The exit status is judged separately: the analyzer answers 1, 2 and 3 for different
/// severities, and what this reports is the issues themselves, so a refusal names what is wrong
/// instead of counting it.
List<String> analyzerIssuesIn(String output) => <String>[
  for (final String line in output.split('\n'))
    if (_issueLine.hasMatch(line)) line.trim(),
];

/// Every file the formatter would change, one per line.
List<String> formatterChangesIn(String output) => <String>[
  for (final String line in output.split('\n'))
    if (_changedLine.firstMatch(line.trimRight())?.group(1) case final String path) path,
];

/// How many files the formatter read, from its own summary line.
///
/// This is the denominator of the check: a clean run that read nothing reads exactly like a clean
/// run that read everything, and the count is the one thing that tells them apart. Null when no
/// summary is in [output], which is itself a red answer.
int? formatterFilesReadIn(String output) {
  for (final String line in output.split('\n')) {
    if (_summaryLine.firstMatch(line.trimRight())?.group(1) case final String count) {
      return int.parse(count);
    }
  }
  return null;
}

final RegExp _issueLine = RegExp(r'^\s*(error|warning|info) - ');
final RegExp _changedLine = RegExp(r'^Changed (.+)$');
final RegExp _summaryLine = RegExp(r'^Formatted (\d+) files?\b');
