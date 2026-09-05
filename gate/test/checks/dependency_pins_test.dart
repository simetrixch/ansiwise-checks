import 'package:ansiwise_checks_tree/audits.dart';

/// dependency-pins — every dependency this package resolves out of git names a release tag.
///
/// WHAT IT JUDGES HERE, PLAINLY: this package's own manifest, which names `package:test`,
/// `package:lints` and the sibling half by path, and therefore states no `ref:` at all. The verdict
/// over this tree is green over nothing, and the test that says how many git dependencies were
/// judged is what makes that readable instead of hiding it. It is declared anyway because the one
/// property this package has to keep is that it reaches nothing that has to be fetched before a
/// gate can start, and a git ref appearing here is the first shape that would take.
void main() => auditDependencyPins();
