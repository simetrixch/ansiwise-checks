import 'package:ansiwise_checks_tree/audits.dart';

/// dependency-pins — every dependency this package resolves out of git names a release tag.
///
/// TWO ARE JUDGED HERE and they are unlike each other. `ansiwise_core` is what this package is
/// built on: it drives a real registry, so it reaches the framework, and whoever resolves THIS
/// package resolves that one too. A branch ref there hands them a framework that changes underneath
/// them under the same name. `ansiwise_checks_tree` is the other half of this same repository,
/// reached out of git rather than by path so that the two halves are released together and read
/// each other at the version they were released at.
///
/// THE SISTER PACKAGE RUNS THE SAME AUDIT over its own manifest, which resolves everything off
/// pub.dev and therefore judges no git dependency at all. Between the two, every manifest of this
/// repository is judged — and the count in each test name is what lets a reader see that rather
/// than take it on trust.
void main() => auditDependencyPins();
