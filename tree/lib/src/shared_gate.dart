/// shared-gate — the gate files that judge nothing are ONE text in every repository that has a gate.
///
/// **Why a copy at all.** The gate resolves the tree: `dart pub get` is its first act, so its own
/// program has to start on a fresh clone where no package has been resolved. A gate that lived in a
/// package would have to be resolved before it could run the resolution. The copy is forced by the
/// mechanism, and nothing here proposes to remove it.
///
/// **What went wrong with it.** Two copies drifted, in both directions and unnoticed. One gained the
/// walk that finds a repository rather than a package — added after a gate printed "every check
/// green" with a second package's sixty-four files never analysed — and the other never got it. One
/// carried an example naming a repository it had been copied out of and never adapted. A repair
/// landing in one copy and not the other is exactly the danger, and nothing reported it.
///
/// **What is compared, and what deliberately is not.** Only the files that judge NOTHING: they name
/// no subject and offer no capability the other lacks. The files that decide something — what a
/// package must satisfy, how a tree is analysed — differ between repositories because the subjects
/// differ, and comparing those would be red for ever and teach nobody anything. The line is not a
/// preference: a file that names a repository cannot be shared, and a file that must be shared
/// cannot name one.
library;

import 'finding.dart';

/// The gate files every repository holds identically, by the name each stands under `tool/gate/`.
///
/// Written out rather than read from a neighbouring checkout: this package is what both repositories
/// depend on, and a check that had to find the OTHER repository on disk could only run where both
/// happen to be cloned side by side.
const Map<String, String> canonicalGateFiles = <String, String>{
  'dart_packages.dart': r'''
/// Finding the Dart packages of a tree.
///
/// Discovery is a search of the tree, not a read of a workspace list. A package that is on disk but
/// not listed is exactly the case the gate must still see: it compiles, imports and breaks a rule
/// like any other, and reading the list would let it do so unwatched.
///
/// The same discovery for the structural checks lives in test/checks/source_tree.dart, over a tree
/// that a counter-probe can plant. This one walks the filesystem, because it runs before anything
/// has been resolved and hands the toolchain a directory to start in.
library;

import 'dart:io';

import 'paths.dart';

/// A Dart package on disk.
final class DartPackage {
  /// Records the package rooted at [directory], declaring itself [name].
  const DartPackage({required this.directory, required this.name});

  /// Where it sits, as this operating system names it.
  final String directory;

  /// What its manifest declares, which is what an import says after `package:`.
  ///
  /// Read from the manifest rather than derived from the directory, because the two differ by
  /// design: a directory written with a hyphen holds a package written with an underscore, since a
  /// Dart package name may not carry a hyphen. Named generically on purpose — this file is one text
  /// in every repository that has a gate, so an example naming one of them is wrong in the others.
  final String name;

  @override
  String toString() => '$name at $directory';
}

/// Directory names that are never source: build output, editor state, and the dependency
/// directories of other ecosystems.
const Set<String> prunedDirectories = <String>{
  '.git',
  '.dart_tool',
  'build',
  'node_modules',
  'Pods',
};

/// Every Dart package under [root], sorted by directory.
///
/// The root itself counts when it carries code — anything else would make a one-package repository
/// invisible to the gate. A manifest at the root of a tree with no `lib/` and no `bin/` of its own
/// declares a workspace rather than a package, and walking it would count every member twice.
List<DartPackage> dartPackagesIn(Directory root) {
  final List<DartPackage> found = <DartPackage>[];
  final bool rootHoldsCode =
      Directory('${root.path}/lib').existsSync() || Directory('${root.path}/bin').existsSync();

  void walk(Directory directory) {
    final File manifest = File('${directory.path}/pubspec.yaml');
    final bool isRoot = directory.path == root.path;
    if (manifest.existsSync() && (!isRoot || rootHoldsCode)) {
      final String? name = declaredPackageName(manifest.readAsStringSync());
      if (name != null) {
        found.add(DartPackage(directory: directory.path, name: name));
      }
    }
    for (final FileSystemEntity entry in directory.listSync(followLinks: false)) {
      if (entry is Directory && !prunedDirectories.contains(baseName(entry.path))) {
        walk(entry);
      }
    }
  }

  walk(root);
  found.sort((DartPackage a, DartPackage b) => a.directory.compareTo(b.directory));
  return found;
}

/// The name [manifest] declares, or null when it declares none.
String? declaredPackageName(String manifest) {
  for (final String line in manifest.split('\n')) {
    final RegExpMatch? match = _nameLine.firstMatch(line.trimRight());
    if (match != null) {
      return match.group(1);
    }
  }
  return null;
}

final RegExp _nameLine = RegExp(r'^name:\s*(\S+)');
''',
  'gate_log.dart': r'''
/// Where the gate says what it is about to do.
///
/// The classes that decide something return it; they never print. A person watching a gate run
/// still needs to know which package is being resolved and which suite is running, and that is what
/// this is for — so a test can drive the same run and read what it announced instead of watching a
/// terminal.
library;

import 'dart:io';

/// Somewhere for the gate to say what it is doing.
abstract interface class GateLog {
  /// Announces the next thing, on its own line.
  void heading(String what);

  /// Says something that is not a step of its own.
  void note(String what);
}

/// The terminal a developer is watching.
final class StdoutGateLog implements GateLog {
  /// Creates a log that writes to standard output.
  const StdoutGateLog();

  @override
  void heading(String what) => stdout.writeln('\n########## $what ##########');

  @override
  void note(String what) => stdout.writeln(what);
}

/// A log that keeps what it was told, for a test that has to read it.
final class CollectedGateLog implements GateLog {
  /// Creates an empty log.
  CollectedGateLog();

  /// Everything the gate said, in order.
  final List<String> said = <String>[];

  @override
  void heading(String what) => said.add(what);

  @override
  void note(String what) => said.add(what);
}
''',
  'paths.dart': r'''
/// The path arithmetic the gate does for itself.
///
/// `package:path` would answer all of this, and nothing under tool/ may import it. The gate is what
/// resolves the tree — `dart pub get` is its first step — so its own program has to start on a fresh
/// clone where no package has been resolved, and a `package:` import would make it unable to start
/// until it had already run. So tool/ imports nothing but `dart:`, and the two things it needs from
/// a path library are here.
library;

import 'dart:io';

/// The last segment of [path], whichever separator this operating system wrote it with.
String baseName(String path) {
  final int cut = path.lastIndexOf(_separator);
  return cut < 0 ? path : path.substring(cut + 1);
}

/// The package a program under `tool/` is part of.
///
/// Taken from where the program's own file sits rather than from the working directory, so `dart run
/// tool/ci.dart` answers the same from anywhere in the tree. [script] is `Platform.script`; it is a
/// parameter rather than read here so that what this resolves to can be asserted.
Directory packageOfToolScript(Uri script) => File.fromUri(script).parent.parent.absolute;

/// The repository [start] sits in: the nearest directory at or above it holding `.git`.
///
/// WHAT THIS IS FOR. The gate checks a REPOSITORY, and a repository is not a package. While this one
/// held a single package the two were the same directory and the difference could not be seen — then
/// a second package arrived, the gate went on walking the first, and it printed `every check green`
/// with sixty-four files of the second never analysed, never formatted-checked and never run. A gate
/// that cannot see half a repository and says every check is green is not a gap in coverage, it is a
/// wrong answer in the shape of a right one.
///
/// Throws [StateError] when there is no `.git` above [start], because then there is no repository to
/// check and every answer this gate could give would be about something else.
Directory repositoryOf(Directory start) {
  Directory directory = start.absolute;
  while (true) {
    if (Directory('${directory.path}/.git').existsSync() ||
        File('${directory.path}/.git').existsSync()) {
      return directory;
    }
    final Directory parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError(
        'no .git at or above ${start.path}, so there is no repository here to check and a run '
        'would report about a tree nobody named',
      );
    }
    directory = parent;
  }
}

final RegExp _separator = RegExp(r'[/\\]');
''',
  'pins.dart': r'''
/// The one toolchain the checks of this repository are true against.
///
/// The version is pinned so a red run is a finding in the tree and not a tool that moved underneath
/// it. It was read from the source named beside it, on the date given: a version recalled from
/// memory is as old as whoever recalled it, which is why the source is part of the record.
///
/// The pin names a requirement, not an installation: tool/gate/version_guard.dart reads the SDK the
/// gate is running on and refuses the run where the two differ, naming what was found and what was
/// expected.
library;

/// The Dart SDK the checks are true against, and the only tool the gate starts.
///
/// storage.googleapis.com/dart-archive/channels/stable/release/latest/VERSION — read 2026-08-17,
/// which answered version 3.13.0, released 2026-08-05, revision da6595cd6bb5. The previous pin was
/// 3.12.2, read from the same source on 2026-08-08; the toolchain on the machine moved under it and
/// this guard refused every run, which is the guard working rather than failing.
const String dartVersion = '3.13.0';
''',
};

/// Every canonical gate file [held] spells differently, or none where the copy is exact.
///
/// [held] is what the repository carries, by the same names. A file the repository does not carry at
/// all is reported too: a gate missing half its plumbing is not a gate that passes.
List<Finding> auditSharedGate(Map<String, String> held) => <Finding>[
  for (final MapEntry<String, String> canonical in canonicalGateFiles.entries)
    if (!held.containsKey(canonical.key))
      Finding(
        'tool/gate/${canonical.key}',
        'this repository has a gate and does not carry ${canonical.key}, which every gate shares',
      )
    else if (held[canonical.key] != canonical.value)
      Finding(
        'tool/gate/${canonical.key}',
        'differs from the one text every gate shares — change it in ansiwise-checks and take the '
            'change to every gate, or move what made it differ into a file that judges something',
      ),
];
