/// The audits that decide whether a plugin holds this framework's contract.
///
/// **An audit takes a tree or a registry and RETURNS findings.** It never asserts, never prints
/// and never exits. That is what lets a counter-probe drive the same audit over a tree it planted,
/// and what keeps a check from being a shell script with Dart syntax.
///
/// **What is here and what is next door.** Here: the audits that need the framework's TYPES —
/// they build a registry's steps, drive them against a fake machine, and read what a program file
/// resolves to. Next door in `ansiwise_checks_tree`: the audits that only read files, which
/// depend on nothing of this organisation so that the framework itself may use them. This library
/// re-exports that one, so a package with a registry names one dependency and gets both.
///
/// **Why it is a package beside the framework rather than part of it.** An audit walks files, so
/// it needs `dart:io`, and the framework's exec-confinement rule forbids that outside
/// `infrastructure/` for everything that SHIPS. This ships nothing: it is development tooling, a
/// dev dependency, never compiled into a binary and never carried onto a machine.
///
/// **Why it is not copied per plugin.** It was, and the copies drifted — measurably. `SourceTree`
/// existed in two repositories and one of them had gained the ability to plant a non-text file,
/// which is how a check that reads content is shown to step past a binary. The other could not, so
/// it had no counter-probe for that case, and nothing reported the gap. A check nobody copied is
/// the purest form of a check that was skipped: it does not go red, it is simply absent.
library;

export 'package:ansiwise_checks_tree/ansiwise_checks_tree.dart';

export 'src/composer_purity.dart';
export 'src/config_validity.dart';
export 'src/declared_answers.dart';
export 'src/dry_safety.dart';
export 'src/idempotence.dart';
export 'src/registry_completeness.dart';
export 'src/registry_reading.dart';
export 'src/reversibility.dart';
export 'src/step_under_probe.dart';
