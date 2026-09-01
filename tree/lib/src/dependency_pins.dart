/// dependency-pins — every dependency a manifest resolves out of git names a release tag.
///
/// These packages produce no file. Whoever depends on one resolves it out of git, so what a caller
/// GETS when it names a `ref:` is the tree standing at that ref — and a ref naming a branch is a
/// different tree the next time anybody pushes. A manifest saying `ref: master` therefore hands
/// every caller whatever was pushed last, at a moment nobody chose, and it looks exactly like a
/// manifest that decided something.
///
/// A dependency with NO `ref:` is the same thing wearing no clothes: pub then follows the default
/// branch of the repository it names. It is reported with the empty ref it states, so deleting the
/// line cannot turn a red manifest green.
///
/// WHAT A RELEASE TAG IS. `<major>.<minor>.<patch>-<channel>-<ts14>`: three numbers carrying no
/// leading zero, a channel that is `alpha`, `beta` or `stable`, and the fourteen digits of the UTC
/// yyyyMMddHHmmss the tag was composed at. There is no `v` prefix, and a bare `0.1.0` is no tag.
/// THIS IS A SECOND SPELLING OF THAT GRAMMAR. The first is `shared/release.ts:22` of the repository
/// that mints releases for everything here — another repository and another language, so nothing in
/// this package can hold the two against each other, and a check that had to find that checkout on
/// disk could only run where both happen to be cloned side by side. What this file can be instead is
/// the ONLY Dart spelling of it: it sits in the package every tree of this family already depends
/// on, so no tree writes the grammar into its own suite and there is one place to change when the
/// first spelling changes.
///
/// `pubspec_overrides.yaml` IS NOT READ, AND THAT IS THE DECISION RATHER THAN AN OVERSIGHT. It is
/// gitignored and points at sibling checkouts, which is how a developer resolves the tree they are
/// working in; it never travels, so nothing it says reaches anybody who depends on this repository.
/// Reading it would give one tree two answers — red on a machine that has the file, green in the run
/// on a fresh clone that does not — and the answer this check exists for is the one about what a
/// caller resolves. So a file is read only when its name is exactly `pubspec.yaml`, and an overrides
/// file beside it is left alone however it resolves its own dependencies.
library;

import 'package:path/path.dart' as p;

import 'finding.dart';
import 'source_tree.dart';

/// The name of a manifest this check reads.
const String manifestName = 'pubspec.yaml';

/// The grammar a `ref:` has to match to be a release tag rather than a branch.
///
/// Anchored at both ends, so a name that merely carries a tag inside it is not one. The numeric
/// parts refuse a leading zero, which is what stops `01.02.03` from standing for `1.2.3` under a
/// second name.
final RegExp releaseTag = RegExp(
  r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-(alpha|beta|stable)-[0-9]{14}$',
);

/// The other shape a ref may take: the full name of a commit.
///
/// WHY A COMMIT IS ADMITTED BESIDE A TAG. What this check is for is that the tree at a ref cannot
/// change under the caller. A tag carries that by convention — nothing stops one being moved onto
/// another tree — while a commit carries it by construction: the name IS the content, and a
/// different tree has a different name. So this is not a relaxation; it is the stronger of the two
/// admitted alongside the one people read more easily.
///
/// WHAT IT IS FOR HERE. ansiwise-cli is the product; ansiwise-core, ansiwise-plugins and
/// ansiwise-checks are its parts and are released by nobody, so there is no tag of theirs to name.
/// Before this, keeping them nameable meant releasing three repositories that build nothing, and
/// their forty-four refs drifted between those releases: measured on 2026-09-01, the twelve plugin
/// packages stood on one commit of this repository while the cli and the core stood on another, and
/// nothing said so.
///
/// FORTY HEX DIGITS, LOWER CASE, ANCHORED. An abbreviated commit is refused: it is a prefix, and a
/// prefix can come to mean a second commit as a repository grows.
final RegExp commitName = RegExp(r'^[0-9a-f]{40}$');

/// One dependency a manifest resolves out of git.
final class GitDependency {
  /// The dependency called [package], resolved by [manifest] at [ref], written on [line].
  const GitDependency({
    required this.manifest,
    required this.package,
    required this.ref,
    required this.line,
  });

  /// The manifest that resolves it, as a path in the tree.
  final String manifest;

  /// The name the manifest gives it, which is what an import says after `package:`.
  final String package;

  /// What is fetched: a release tag, a branch, or the empty string when the manifest states none.
  final String ref;

  /// The line of [manifest] the finding points at, counted from one.
  ///
  /// The `ref:` where there is one, and the `git:` where there is not — a manifest that states no
  /// ref has no line to blame but the one that opened the git block.
  final int line;

  /// Whether [ref] is a release tag rather than a branch.
  bool get isPinned => releaseTag.hasMatch(ref) || commitName.hasMatch(ref);

  @override
  String toString() => '$package at ${ref.isEmpty ? 'no ref' : ref} ($manifest:$line)';
}

/// The scan itself, over a tree it is given rather than over the repository it lives in.
final class DependencyPins {
  /// Judges [tree].
  const DependencyPins(this.tree);

  /// The tree being judged.
  final SourceTree tree;

  /// The manifests this check reads, sorted.
  ///
  /// This is the denominator: a run in which it is empty read nothing, and its silence must not be
  /// taken for agreement.
  List<String> get manifestsRead {
    final List<String> paths = <String>[
      for (final MapEntry<String, String?> entry in tree.files.entries)
        if (entry.value != null && p.posix.basename(entry.key) == manifestName) entry.key,
    ];
    return paths..sort();
  }

  /// Every manifest that is in the tree and could not be read as text, sorted.
  ///
  /// A manifest whose bytes are not text drops out of [manifestsRead], and it would drop out of the
  /// packages the coverage assertion compares against as well — the name is read from the same
  /// bytes — so both sides of that comparison would lose it together and agree about a file nobody
  /// opened. Named here so the audit can REFUSE over it instead, which is what this family's own
  /// rule says a scan does when it cannot see its material.
  List<String> get manifestsUnread {
    final List<String> paths = <String>[
      for (final MapEntry<String, String?> entry in tree.files.entries)
        if (entry.value == null && p.posix.basename(entry.key) == manifestName) entry.key,
    ];
    return paths..sort();
  }

  /// Every dependency the read manifests resolve out of git, in the order the manifests write them.
  List<GitDependency> get judged => <GitDependency>[
    for (final String manifest in manifestsRead)
      ...gitDependenciesIn(manifest, tree.textOf(manifest) ?? ''),
  ];

  /// How many `git:` keys stand in the read manifests.
  ///
  /// A COARSE SECOND COUNT, and it is here because the reader below tracks blocks and a block
  /// tracker that quietly stops tracking answers "no git dependencies" — which reads exactly like a
  /// tree that has none. This count knows nothing about which dependency or which ref, and cannot
  /// take the reader's place; what it can say is HOW MANY there are, so the two disagreeing is what
  /// says the reader stopped working.
  int get gitKeysSeen => <String>[
    for (final String manifest in manifestsRead)
      for (final String line in linesOf(tree.textOf(manifest) ?? ''))
        if (_gitKey.hasMatch(line.trimLeft()) || _inlineGitDependency.hasMatch(line.trimLeft()))
          line,
  ].length;

  /// Every git dependency that names something other than a release tag.
  ///
  /// The subject is the MANIFEST, because that is the file a person opens to fix it, and the
  /// dependency and the ref stand in the sentence beside the line number.
  List<Finding> get findings => <Finding>[
    for (final GitDependency dependency in judged)
      if (!dependency.isPinned)
        Finding(dependency.manifest, _whatIsWrong(dependency), line: dependency.line),
  ];
}

/// Every dependency [text] resolves out of git, in the order [manifest] writes them.
///
/// The text is a parameter rather than a path, so a probe can drive the same reading over a manifest
/// it wrote itself.
///
/// READ AS LINES rather than as YAML. What is walked is the two levels a manifest writes a git
/// dependency in — the name at one indent, `git:` under it, and `url:` and `ref:` under that — and a
/// dependency block carrying no `git:` is not a git dependency and is not answered here. That last
/// part is what keeps a `hosted:` block, which also states a `url:` and never a `ref:`, out of the
/// findings.
List<GitDependency> gitDependenciesIn(String manifest, String text) {
  final List<String> lines = linesOf(text);
  final List<GitDependency> found = <GitDependency>[];
  String? package;
  int nameIndent = -1;
  int gitIndent = -1;
  int gitLine = -1;
  String? ref;
  int refLine = -1;

  void close() {
    if (package case final String named when gitLine >= 0) {
      found.add(
        GitDependency(
          manifest: manifest,
          package: named,
          ref: ref ?? '',
          line: (ref == null ? gitLine : refLine) + 1,
        ),
      );
    }
    package = null;
    nameIndent = -1;
    gitIndent = -1;
    gitLine = -1;
    ref = null;
    refLine = -1;
  }

  for (int index = 0; index < lines.length; index++) {
    final String line = lines[index];
    final String content = line.trimLeft();
    if (content.isEmpty || content.startsWith('#')) {
      continue;
    }
    final int indent = line.length - content.length;
    if (package != null && indent <= nameIndent) {
      close();
    }
    if (package == null) {
      // The whole dependency on one line, braces and all. It opens no block and closes none, so it
      // is answered here and the walk goes on to the next line.
      final RegExpMatch? inlineWhole = indent > 0 ? _inlineGitDependency.firstMatch(content) : null;
      if (inlineWhole != null) {
        final RegExpMatch? statedRef = _flowRef.firstMatch(content);
        found.add(
          GitDependency(
            manifest: manifest,
            package: inlineWhole.group(1)!,
            ref: statedRef == null ? '' : _unquoted(statedRef.group(1)!.trim()),
            line: index + 1,
          ),
        );
        continue;
      }
      final RegExpMatch? named = _blockName.firstMatch(content);
      // A key at the root of the manifest opens a section — dependencies, dev_dependencies,
      // dependency_overrides — and never a dependency, so the indent is what tells the two apart.
      if (named != null && indent > 0) {
        package = named.group(1);
        nameIndent = indent;
      }
      continue;
    }
    if (gitLine < 0) {
      final RegExpMatch? git = _gitKey.firstMatch(content);
      if (git != null) {
        gitLine = index;
        gitIndent = indent;
        // `git:` carrying its value on the same line is the flow form, where the ref stands inside
        // braces rather than on a line of its own. A short form naming only a url states no ref at
        // all, which is what the empty string then reports.
        final RegExpMatch? inline = _flowRef.firstMatch(git.group(1)!);
        if (inline != null) {
          ref = _unquoted(inline.group(1)!);
          refLine = index;
        }
      }
      continue;
    }
    if (indent > gitIndent) {
      final RegExpMatch? stated = _refKey.firstMatch(content);
      if (stated != null) {
        ref = _unquoted(stated.group(1)!.trim());
        refLine = index;
      }
    }
  }
  close();
  return found;
}

String _whatIsWrong(GitDependency dependency) => dependency.ref.isEmpty
    ? '${dependency.package} is resolved out of git and this manifest names no ref for it, so pub '
          'follows the default branch of that repository and whoever depends on this tree gets '
          'whatever was pushed there last — name a release tag'
    : '${dependency.package} is resolved out of git at ref "${dependency.ref}", which is no release '
          'tag: a tag is <major>.<minor>.<patch>-<channel>-<ts14>, so this names a branch or a name '
          'no release ever cut, and what it resolves to changes underneath everybody who reads it';

String _unquoted(String text) {
  for (final String quote in <String>["'", '"']) {
    if (text.length >= 2 && text.startsWith(quote) && text.endsWith(quote)) {
      return text.substring(1, text.length - 1);
    }
  }
  return text;
}

/// A dependency name at the head of its block: a name with nothing behind the colon.
///
/// A dependency written as one line carries its value there and is no git dependency, so it ends a
/// block rather than opening one.
final RegExp _blockName = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*):\s*$');

/// The key that says a dependency is resolved out of git, with whatever it carries behind it.
final RegExp _gitKey = RegExp(r'^git:(.*)$');

/// A whole git dependency written on the name line as a flow mapping, braces and all.
///
/// `pub` accepts `foo: {git: {url: https://x, ref: master}}`, and it is neither a block name — the
/// colon carries a value — nor a `git:` key, which is anchored at the start of its own line. Held
/// separately rather than by loosening either of those: widening the block name would take every
/// one-line dependency for the head of a block, and widening the git key would find the word inside
/// a url. What follows the brace is handed to the same flow reader the half-flow form uses.
final RegExp _inlineGitDependency = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*):[ \t]*\{.*\bgit[ \t]*:');

/// The ref a git block states on a line of its own.
final RegExp _refKey = RegExp(r'^ref:[ \t]+(\S.*)$');

/// The ref a flow mapping states inside braces.
final RegExp _flowRef = RegExp(r'ref:[ \t]*([^,}\s]+)');
