/// hosted-only — this package reaches nothing that is not on pub.dev.
///
/// **WHY THIS PACKAGE AND NOT ANY OTHER.** Its own description says it: audits that read a tree of
/// files, depending on nothing of this organisation. That sentence is what lets the FRAMEWORK take
/// it as a dev dependency without giving up framework independence — the framework may reach nothing
/// of ours, and this is the one thing of ours it reaches, on the promise that it leads nowhere.
///
/// A promise in a description is not a guarantee. Nothing stopped somebody adding a dependency here
/// tomorrow, and the framework's own check could not have caught it: from over there this package is
/// a GIT dependency, which that check cannot follow, so what it leads to is unknown. It reports the
/// unknown rather than assuming it clean, which is right — and it means the answer has to be given
/// on THIS side, where the manifest is readable.
///
/// So the two halves are: over there, a named exception saying this package is held here; here, the
/// holding. Neither is worth anything without the other, and each names the other so a reader
/// arriving at one finds the second.
///
/// **WHAT COUNTS AS HOSTED.** A dependency written as a bare version constraint — `path: ^1.9.1` —
/// comes from pub.dev. Anything with a `git:`, a `path:` or a `hosted:` block under it does not, and
/// is reported whichever of the three sections it stands in. A dev dependency counts the same as a
/// dependency: it is the same coupling in a different hat, and the whole point here is that this
/// package can be resolved by somebody who has nothing else of ours.
///
/// **WHAT IT DOES NOT REACH.** It reads THIS package's manifest and no other, so it says nothing
/// about what a hosted dependency itself pulls in — pub.dev is taken as the boundary, exactly as the
/// framework's own check takes it. It does not read `pubspec_overrides.yaml`: that file is gitignored
/// and names sibling checkouts, so reading it would answer one tree differently on a developer's
/// machine and in a fresh clone — and answering differently in those two places is the defect this
/// check exists for.
library;

import 'dependency_pins.dart' show manifestName;
import 'source_tree.dart';

/// The three sections a manifest declares dependencies in.
const List<String> dependencySections = <String>[
  'dependencies',
  'dev_dependencies',
  'dependency_overrides',
];

/// One dependency this package names that pub.dev does not serve.
final class UnhostedDependency {
  /// The dependency called [package] is resolved [by] something other than pub.dev, on [line].
  const UnhostedDependency({required this.package, required this.by, required this.line});

  /// The name the manifest gives it.
  final String package;

  /// What resolves it: `git`, `path` or `hosted`.
  final String by;

  /// The line the block opens at, counted from one.
  final int line;

  @override
  String toString() =>
      '$package is resolved by $by at $manifestName:$line — this package is taken by the framework '
      'on the promise that it reaches nothing of ours, and a dependency pub.dev does not serve is '
      'either one of ours or one nobody who clones this can resolve';
}

/// Every dependency of [manifest] that pub.dev does not serve, in the order they stand.
///
/// Read as lines rather than as YAML, the way every other audit here reads a manifest: this package
/// is resolved by people who have nothing else of ours, so it carries no parser it does not need.
List<UnhostedDependency> unhostedDependenciesIn(String manifest) {
  final List<String> lines = linesOf(manifest);
  final List<UnhostedDependency> found = <UnhostedDependency>[];
  String? section;
  String? package;
  int packageIndent = -1;
  int packageLine = -1;

  for (int index = 0; index < lines.length; index++) {
    final String content = lines[index].trimLeft();
    if (content.isEmpty || content.startsWith('#')) {
      continue;
    }
    final int indent = lines[index].length - content.length;
    if (indent == 0) {
      section = content.endsWith(':') ? content.substring(0, content.length - 1) : null;
      package = null;
      packageIndent = -1;
      continue;
    }
    if (section == null || !dependencySections.contains(section)) {
      continue;
    }
    // A name with nothing behind the colon opens a block; anything else is a version constraint,
    // which is what a hosted dependency looks like.
    if (package == null || indent <= packageIndent) {
      final int colon = content.indexOf(':');
      package = colon < 0 ? null : content.substring(0, colon).trim();
      packageIndent = indent;
      packageLine = index + 1;
      continue;
    }
    final int colon = content.indexOf(':');
    final String key = colon < 0 ? content : content.substring(0, colon).trim();
    if (key == 'git' || key == 'path' || key == 'hosted') {
      if (package case final String named) {
        found.add(UnhostedDependency(package: named, by: key, line: packageLine));
        // One report per dependency: a git block also carries a path, and naming both would say
        // there are two problems where there is one.
        package = null;
        packageIndent = -1;
      }
    }
  }
  return found;
}
