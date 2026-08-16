/// The audits that decide something by READING A TREE OF FILES, and nothing else.
///
/// **This package depends on nothing of this organisation, and that is its whole reason for
/// standing apart.** The framework is the bottom of the stack and a rule says so: it may reach
/// nothing of ours, so that no unit of ours becomes part of the core through the back door. The
/// framework also has to be able to check ITSELF — its line endings, its naming, its word purity,
/// the case of its own directives. Those two only fit together if the audits it uses sit beside
/// it rather than above it. They do, here.
///
/// The other half — the audits that drive a REGISTRY, and so must know the framework's types —
/// is the package next door. A package that has a registry takes that one; it re-exports this
/// one, so nothing needs both by name.
library;

export 'src/analysis.dart';
export 'src/declared_checks.dart';
export 'src/directive_case.dart';
export 'src/exec_confinement.dart';
export 'src/finding.dart';
export 'src/installation_programs.dart';
export 'src/line_endings.dart';
export 'src/naming.dart';
export 'src/source_tree.dart';
export 'src/word_purity.dart';
