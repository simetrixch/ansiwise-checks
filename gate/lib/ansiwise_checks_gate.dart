/// The gate: the one program that runs every check of a repository and answers with one verdict.
///
/// **Why this is a package and no longer a copy under each repository's `tool/`.** The gate resolves
/// the tree, and for a long time that was read as meaning the gate could not itself be resolved —
/// so `ansiwise-core` and `ansiwise-cli` each carried the same eleven files, five of which had
/// drifted. What the callers actually do is resolve the package the gate sits in FIRST and start the
/// gate second: `dart pub get`, then `dart run tool/ci.dart`, in every build script, every check
/// script and every workflow. The resolution the gate performs is the one over every package of the
/// repository, which is what the analyzer, the formatter and the suites read.
///
/// **What it still may not do is grow a dependency.** This package reaches nothing but `dart:`,
/// because whatever it reached would have to be resolved on every machine before any gate in the
/// family could start.
///
/// **A repository composes its own gate out of these parts.** What is generic lives here — finding
/// the packages of a tree, starting the toolchain, refusing the wrong SDK, refusing a split
/// composition, the sequence and the verdict. What decides something about ONE product — which
/// plugins its binary carries, what a release tag is made of, how its executable is compiled —
/// stays in that product's own `tool/`.
library;

export 'src/analysis_check.dart';
export 'src/dart_packages.dart';
export 'src/dart_toolchain.dart';
export 'src/declared_checks.dart';
export 'src/fake_dart_toolchain.dart';
export 'src/gate_log.dart';
export 'src/package_gate.dart';
export 'src/paths.dart';
export 'src/pins.dart';
export 'src/real_dart_toolchain.dart';
export 'src/resolved_packages.dart';
export 'src/version_guard.dart';
