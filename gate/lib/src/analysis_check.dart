/// analysis — the analyzer and the formatter are clean for every Dart package of a tree.
///
/// `dart analyze --fatal-infos --fatal-warnings` with this family's analysis_options is not a style
/// pass. strict-casts, strict-inference and strict-raw-types are on, so an implicit cast, an
/// inferred `dynamic` and a raw generic are each reported as an info — and each is a type nobody
/// chose. `unused_import` and `dead_code` are raised to errors, which is the no-leftovers rule of
/// this project enforced by a tool rather than by a reviewer. `dart format --set-exit-if-changed` is
/// what keeps a diff about the change instead of about the whitespace.
///
/// THIS CANNOT BE A TEST OF THE PACKAGE IT JUDGES. A test is compiled by the analysis it is meant
/// to fail on, so the day the package stops analysing, the check meant to say so is the thing that
/// did not compile: either the package analyses and the test has nothing to report, or it does not
/// and the test never starts. It is a program the gate runs instead — `dart run tool/analysis.dart`
/// — and that is outside the suite without being outside Dart.
///
/// What it decides is here and what prints it is that program, so the whole sequence can be driven
/// by a test against a scripted toolchain on a machine with neither tool installed. Reading the two
/// tools correctly is the part that rots silently, and test/checks/analysis_check_test.dart is what
/// holds it: a scripted answer for the parsing, and the real analyzer and formatter over a planted
/// package for the day either tool changes what it writes.
///
/// A PACKAGE WHOSE DEPENDENCIES ARE NOT RESOLVED IS NOT ANALYSED, AND IS NAMED FOR IT. The analyzer
/// answers a package it cannot resolve with one error per import and then hundreds more about every
/// name those imports would have brought in — a missing toolchain reported as a tree full of
/// defects, which is the one answer nobody can act on. So the package config that applies is read
/// first, and a package it does not cover is reported NOT ANALYSED with its name on the verdict
/// line. **That is a gap and it counts as one: the reading is not green while any package stands in
/// it.** A run that named the gap and then answered OK would be a check reporting that it did not
/// look, in the shape of a pass.
///
/// THE FORMATTER IS NOT ASKED ABOUT SUCH A PACKAGE EITHER, though it parses and never resolves. Its
/// page width is not a default it carries: analysis_options.yaml sets it, and every package of this
/// family reaches the setting through a `package:` include, which only
/// .dart_tool/package_config.json can resolve. Without one the formatter falls back to eighty
/// columns where these trees are written to a hundred, and reports every file as one it would
/// change — thirty-four of them in a release run whose clone of a private dependency had failed, and
/// not one of them about the code.
library;

import 'dart:io';

import 'dart_packages.dart';
import 'dart_toolchain.dart';

/// How much weight the analyzer gives an issue.
///
/// All three count. `--fatal-infos --fatal-warnings` is what makes these analysis_options mean what
/// they say: with strict-casts, strict-inference and strict-raw-types on, an implicit cast, an
/// inferred `dynamic` and a raw generic are each reported as an info, and each is a type the author
/// never chose.
enum AnalyzerSeverity {
  /// The code does not compile, or breaks a rule raised to an error.
  error,

  /// Something the analyzer reports as a warning by default.
  warning,

  /// Something the analyzer reports as an info by default.
  info,
}

/// One thing wrong with a package, as one of the two tools reported it.
///
/// A value with the tool's answer taken apart rather than the line it wrote, so a caller can count
/// the errors, group by package or print them however it likes without parsing anything a second
/// time.
sealed class AnalysisFinding {
  const AnalysisFinding(this.package);

  /// The package it is about, as its manifest names it.
  final String package;
}

/// The analyzer reported something.
final class AnalyzerIssue extends AnalysisFinding {
  /// Records an issue in [package], reported at [severity].
  const AnalyzerIssue(super.package, {required this.severity, required this.message});

  /// How much weight the analyzer gave it.
  final AnalyzerSeverity severity;

  /// What it said, without the severity it said it at.
  final String message;

  @override
  String toString() => '$package: ${severity.name} - $message';
}

/// The formatter would rewrite a file.
final class FormatterChange extends AnalysisFinding {
  /// Records that [file] of [package] is not formatted.
  const FormatterChange(super.package, this.file);

  /// The file, as the formatter named it.
  final String file;

  @override
  String toString() => '$package: dart format would change $file';
}

/// What the analyzer and the formatter made of a set of packages.
final class AnalysisReading {
  /// Records what each package turned out to be.
  const AnalysisReading({
    required this.findings,
    required this.analysed,
    required this.notAnalysed,
  });

  /// Everything the two tools reported, analyzer before formatter, package by package.
  final List<AnalysisFinding> findings;

  /// The packages whose dependencies were resolved, so the analyzer could say something true.
  final List<String> analysed;

  /// The packages nothing here resolved, named because a gap has to read as one.
  final List<String> notAnalysed;

  /// Whether the tools found nothing, were pointed at something, and left no package unlooked at.
  ///
  /// The three conditions are three different ways a run can be empty of findings and mean nothing.
  /// A run over no package finds nothing for the same reason a run over a clean one does. A run that
  /// skipped every package finds nothing too, and the skipping is the whole story. Only a run that
  /// asked both tools about every package it was given and got nothing back is a pass.
  bool get green => findings.isEmpty && notAnalysed.isEmpty && analysed.isNotEmpty;

  /// What this run decided, in the one line a person reads.
  String get verdictLine {
    if (analysed.isEmpty && notAnalysed.isEmpty) {
      return 'analysis: FAIL — no Dart package was found to judge, so this check measured nothing';
    }
    if (findings.isNotEmpty) {
      return 'analysis: FAIL — ${findings.length} finding(s) above';
    }
    if (notAnalysed.isNotEmpty) {
      return 'analysis: FAIL — ${notAnalysed.length} package(s) were NOT ANALYSED — '
          '${notAnalysed.join(', ')} — because nothing here resolved their dependencies, so '
          'neither tool was asked about them';
    }
    // THE FLAGS ARE NOT SPELLED HERE, and this is the one place they used to be spelled twice.
    // This reading is handed a [DartToolchain] and never sees how it starts a tool, so a line
    // naming --fatal-infos was a claim about an invocation it cannot observe: with the flag taken
    // out of [RealDartToolchain.analyzerArgv] this line went on naming it, and a tree with nothing
    // at info level answered OK under a sentence that was no longer true. The invocation is written
    // once, where it is made, and the check that judges it plants a fault that only reports at info.
    return 'analysis: OK — the analyzer and the formatter are clean for all '
        '${analysed.length} Dart package(s)';
  }
}

/// The analyzer and the formatter, over a set of packages.
final class AnalysisCheck {
  /// Judges [packages] with [toolchain].
  const AnalysisCheck({required this.toolchain, required this.packages});

  /// How the two tools are started.
  final DartToolchain toolchain;

  /// What is judged.
  final List<DartPackage> packages;

  /// Runs both tools over every package.
  ///
  /// EVERY PACKAGE AND BOTH TOOLS RUN EVEN AFTER AN EARLIER ONE REPORTED SOMETHING. One finding
  /// hiding the rest is how the next run turns up a second problem that was there all along.
  Future<AnalysisReading> run() async {
    final List<AnalysisFinding> findings = <AnalysisFinding>[];
    final List<String> analysed = <String>[];
    final List<String> notAnalysed = <String>[];

    for (final DartPackage package in packages) {
      if (!packageIsResolved(package)) {
        notAnalysed.add(package.name);
        continue;
      }
      analysed.add(package.name);
      findings.addAll(
        analyzerIssuesIn(
          await toolchain.analyze(directory: package.directory),
          package: package.name,
        ),
      );
      findings.addAll(
        formatterChangesIn(
          await toolchain.format(directory: package.directory),
          package: package.name,
        ),
      );
    }

    return AnalysisReading(findings: findings, analysed: analysed, notAnalysed: notAnalysed);
  }
}

/// Every issue in what the analyzer wrote about [package], one per line.
///
/// The exit status is not read: the analyzer answers 1, 2 and 3 for different severities and 0 for
/// a run that found nothing, and what this reports is the issues themselves. It writes a header and
/// a count around them, and neither is an issue.
List<AnalyzerIssue> analyzerIssuesIn(ToolRun run, {required String package}) => <AnalyzerIssue>[
  for (final String line in run.output.split('\n'))
    if (_issueLine.firstMatch(line.trimRight()) case final RegExpMatch match)
      if (match.group(1) case final String severity)
        if (match.group(2) case final String message)
          AnalyzerIssue(
            package,
            severity: AnalyzerSeverity.values.byName(severity),
            message: message.trim(),
          ),
];

/// Every file of [package] the formatter would change, one per line.
List<FormatterChange> formatterChangesIn(ToolRun run, {required String package}) =>
    <FormatterChange>[
      for (final String line in run.output.split('\n'))
        if (_changedLine.firstMatch(line.trimRight())?.group(1) case final String file)
          FormatterChange(package, file),
    ];

/// Whether the package config that applies to [package] knows [package].
///
/// A config that does not know the package cannot know its dependencies either, so every import in
/// it is unresolved and every issue the analyzer would report is about that and nothing else.
bool packageIsResolved(DartPackage package) {
  final File? config = packageConfigFor(package.directory);
  if (config == null) {
    return false;
  }
  return configNamesPackage(config.readAsStringSync(), package.name);
}

/// The package config the analyzer would use for [directory]: the nearest one at or above it.
///
/// This is the analyzer's own rule, and following it is what lets the answer above be about the same
/// files the analyzer will read. A workspace member has none of its own — one resolution at the
/// workspace root covers every member — and a package that resolves on its own has one beside it.
File? packageConfigFor(String directory) {
  Directory current = Directory(directory).absolute;
  while (true) {
    final File config = File('${current.path}/.dart_tool/package_config.json');
    if (config.existsSync()) {
      return config;
    }
    final Directory parent = current.parent;
    if (parent.path == current.path) {
      return null;
    }
    current = parent;
  }
}

/// Whether [configText] names [packageName] among the packages it resolves.
bool configNamesPackage(String configText, String packageName) =>
    RegExp('"name"\\s*:\\s*"${RegExp.escape(packageName)}"').hasMatch(configText);

final RegExp _issueLine = RegExp(r'^\s*(error|warning|info) - (.*)$');
final RegExp _changedLine = RegExp(r'^Changed (.+)$');
