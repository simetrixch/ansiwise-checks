import 'package:ansiwise_checks_tree/audits.dart';

/// dependency-pins — every dependency this package resolves out of git names a release tag.
///
/// A package here produces no file. Whoever depends on one resolves it out of git and gets the tree
/// standing at the ref it named, so a ref naming a branch hands them a different tree the next time
/// anybody pushes, under the same name and with nothing to notice it by.
///
/// WHAT IT JUDGES HERE, PLAINLY: this package's own manifest, which today resolves everything off
/// pub.dev and therefore states no `ref:` at all. So the verdict over this tree is green over
/// nothing, and the test that says how many git dependencies were judged is what makes that
/// readable instead of hiding it. What is really proven in this run is the reader and its refusal,
/// on the manifests the counter-probe writes — five shapes it must refuse and three it must leave
/// alone. The trees that resolve each other out of git run the same audit from their own suites.
void main() => auditDependencyPins();
