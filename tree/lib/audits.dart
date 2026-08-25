/// The SUITES that drive the tree audits, and every counter-probe that proves one can go red.
///
/// The split from `ansiwise_checks_tree.dart` is the same one the registry half makes: that
/// library holds what DECIDES and returns findings without asserting, this one holds what DRIVES
/// — it registers the assertions, states how much was covered, and plants the defects that show
/// each scan really goes red. It reaches `package:test`, which is why it is a library of its own.
library;

export 'src/audits/analysis_audit.dart';
export 'src/audits/captured_refusal_audit.dart';
export 'src/audits/carried_arguments_audit.dart';
export 'src/audits/case_sensitivity_audit.dart';
export 'src/audits/declared_checks_audit.dart';
export 'src/audits/dependency_pins_audit.dart';
export 'src/audits/exec_confinement_audit.dart';
export 'src/audits/hosted_only_audit.dart';
export 'src/audits/line_endings_audit.dart';
export 'src/audits/naming_audit.dart';
export 'src/audits/refused_reading_audit.dart';
export 'src/audits/declared_arguments_audit.dart';
export 'src/audits/word_purity_audit.dart';
