import 'package:ansiwise_checks_tree/audits.dart';

/// analysis — the analyzer and the formatter are clean over this package's own tree.
///
/// A gate runs the two tools over the packages of the repository the GATE lives in, and no gate
/// lives here — so this package answers them from its own suite, the way it answers its other
/// checks.
void main() => auditAnalysis();
