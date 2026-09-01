/// The suite that drives [DependencyPins] over one tree, with the counter-probe beside it.
library;

import 'package:test/test.dart';

import '../dependency_pins.dart';
import '../finding.dart';
import '../source_tree.dart';

/// Runs the dependency-pins audit over [tree], or over the repository this suite sits in.
///
/// WHAT IT STATES: how many manifests were read, that every package of the tree has its manifest
/// among them, and how many git dependencies were judged.
///
/// THE COUNT OF GIT DEPENDENCIES IS NOT ASSERTED TO BE ABOVE ZERO, and that is on purpose: a tree
/// whose packages all come off pub.dev has none, and demanding one would turn such a tree red for
/// being what it is. What answers the question a zero would otherwise leave open — did the reader
/// find nothing, or has it stopped reading? — is the coarse second count of `git:` keys asserted
/// beside it, plus the counter-probe, where the same reader is handed a manifest that has some.
///
/// SO READ THE NUMBER IN THE TEST NAME BEFORE READING THE GREEN. A run that judged zero says
/// nothing whatever about the tree it ran in, and the tree this audit currently runs in is one of
/// those: `ansiwise-checks/tree` resolves nothing out of git. The dependencies this check exists
/// for stand in the OTHER trees of the family and are counted in the ticket that pins them — and
/// until that pinning happens there is nothing to pin to, because not one of those repositories has
/// cut a release tag. Wiring this audit into their suites is therefore part of the act that pins
/// them, not a step that can be taken first: switched on today it would refuse every one of them
/// for a state nobody can leave.
void auditDependencyPins({SourceTree? tree}) {
  final DependencyPins check = DependencyPins(tree ?? SourceTree.on(repositoryRoot()));
  final int manifests = check.manifestsRead.length;
  final int judged = check.judged.length;

  test('$manifests manifest(s) were read, and every package of this tree has one among them', () {
    expect(
      check.manifestsRead,
      isNotEmpty,
      reason: 'no manifest was read, so this check measured nothing at all',
    );
    expect(
      check.manifestsUnread,
      isEmpty,
      reason:
          'a manifest of this tree could not be read as text. It is absent from what was judged AND '
          'from the packages the next assertion compares against, because both are read out of the '
          'same bytes — so the two would agree about a file nobody opened. What that file resolves '
          'is unknown rather than fine',
    );
    expect(
      check.manifestsRead,
      containsAll(<String>[
        for (final String directory in check.tree.packages.keys)
          directory.isEmpty ? manifestName : '$directory/$manifestName',
      ]),
      reason:
          'a package of this tree has a manifest this scan did not read, so the walk covered a '
          'fragment of the tree and reported about the rest by silence',
    );
  });

  test('$judged git dependency(ies) were judged, one for every git: this tree writes', () {
    expect(
      check.judged,
      hasLength(check.gitKeysSeen),
      reason:
          'the manifests write ${check.gitKeysSeen} git: key(s) and the reader answered $judged '
          'dependency(ies), so it lost track of a block and passed over what stood in it',
    );
  });

  test('every dependency resolved out of git names a release tag', () {
    expect(
      check.findings,
      isEmpty,
      reason:
          'these packages produce no file, so what a caller gets is the tree standing at the ref it '
          'named — and a ref naming a branch is a different tree the next time anybody pushes',
    );
  });

  group('counter-probe', () {
    // Five defect shapes and three innocent ones. The innocent ones are the half that is easy to
    // leave out: a reader that reported every git dependency would pass all five defect probes and
    // be useless, and a reader that read the overrides file too would be red on the machine that
    // has one and green in the run that does not.

    final DependencyPins planted = DependencyPins(
      SourceTree.planted(<String, String?>{
        manifestName: _plantedManifest,
        'pubspec_overrides.yaml': _plantedOverrides,
        'lib/planted.dart': 'const int x = 1;\n',
      }),
    );
    final List<Finding> reported = planted.findings;

    // THE LINE EACH ONE IS EXPECTED AT IS WRITTEN OUT, not derived from the manifest the way the
    // reader derives it. A number computed here by walking the same text would agree with the
    // reader however wrong both were, and the attribution — which of eight dependencies a finding
    // belongs to — is exactly what a person uses the line for. Written out, editing the manifest
    // above turns this red until somebody counts again, which is the point.
    for (final (String dependency, int line, String what) in <(String, int, String)>[
      ('at_master', 13, 'the default branch'),
      ('at_a_branch', 17, 'a branch that is not the default one'),
      ('at_a_prefixed_version', 21, 'a version wearing a v, which this grammar has no room for'),
      ('at_a_bare_version', 25, 'three numbers with no channel and no stamp, which no release cut'),
      ('at_no_ref', 27, 'no ref at all, which follows the default branch without naming it'),
      ('at_inline_flow', 29, 'the default branch, with the whole dependency inside braces'),
      (
        'at_a_short_commit',
        38,
        'an abbreviated commit, which is a PREFIX — and a prefix comes to mean a second commit as '
            'a repository grows, so it names no one tree for good',
      ),
    ]) {
      test('$dependency names $what and is reported at line $line', () {
        final Iterable<Finding> found = _about(reported, dependency);
        expect(found, hasLength(1), reason: 'this scan cannot go red on $what');
        expect(
          found.single.subject,
          manifestName,
          reason: 'the manifest is the file a person opens to fix it',
        );
        expect(
          found.single.line,
          line,
          reason:
              'a manifest naming eight dependencies needs the line to say WHICH one, and a line '
              'that is merely present rather than right sends a person to the wrong row',
        );
      });
    }

    test('the ref it refuses stands in the refusal', () {
      expect(
        _about(reported, 'at_a_branch').single.what,
        contains('release/2026-08'),
        reason:
            'a refusal that names the dependency and not the ref makes the reader open the file to '
            'find out what this check even read',
      );
    });

    for (final String dependency in <String>[
      'at_a_release_tag',
      // A COMMIT IS A PIN, and the stronger of the two: a tag can be moved onto another tree,
      // a commit cannot, because its name IS its content. It is what a manifest names where the
      // repository it depends on is released by nobody — which is every part of ansiwise-cli.
      'at_a_commit',
      'at_a_path',
      'at_inline_flow_pinned',
    ]) {
      test('$dependency is left alone', () {
        expect(
          _about(reported, dependency),
          isEmpty,
          reason: 'a scan that reported every dependency would pass every probe above',
        );
      });
    }

    test('the overrides file beside the manifest is not read', () {
      expect(
        planted.manifestsRead,
        isNot(contains('pubspec_overrides.yaml')),
        reason:
            'it is gitignored and points at sibling checkouts, so reading it would answer one tree '
            'differently on a developer machine and on a fresh clone',
      );
      expect(about(reported, 'pubspec_overrides.yaml'), isEmpty);
    });

    test('THE PLANTED DEFECT: a manifest that is not text is named rather than dropped', () {
      final DependencyPins blind = DependencyPins(
        SourceTree.planted(<String, String?>{
          manifestName: _plantedPinnedManifest,
          'unreadable/pubspec.yaml': null,
        }),
      );
      expect(
        blind.manifestsUnread,
        <String>['unreadable/pubspec.yaml'],
        reason:
            'dropped silently it would be missing from the judged side and from the package side at '
            'once, and the coverage assertion compares those two against each other',
      );
      expect(
        blind.findings,
        isEmpty,
        reason: 'what it could not read it must not report a finding about either',
      );
    });

    test('a manifest whose git dependencies are all pinned reports nothing', () {
      expect(
        DependencyPins(
          SourceTree.planted(<String, String?>{manifestName: _plantedPinnedManifest}),
        ).findings,
        isEmpty,
        reason: 'a scan that reported everything would be green for nothing here',
      );
    });
  });
}

/// The findings [found] carries about the dependency called [package].
///
/// Matched on the sentence rather than on the subject, because every finding of one manifest carries
/// that manifest as its subject and the dependency is what tells them apart.
Iterable<Finding> _about(Iterable<Finding> found, String package) =>
    found.where((Finding finding) => finding.what.startsWith('$package '));

/// A manifest carrying every shape this check decides about, defect and innocent alike.
const String _plantedManifest = '''
name: planted_package

dependencies:
  at_a_release_tag:
    git:
      url: https://example.invalid/somebody/pinned.git
      ref: 0.1.0-alpha-20260821194500
  at_a_path:
    path: ../beside
  at_master:
    git:
      url: https://example.invalid/somebody/one.git
      ref: master
  at_a_branch:
    git:
      url: https://example.invalid/somebody/two.git
      ref: release/2026-08
  at_a_prefixed_version:
    git:
      url: https://example.invalid/somebody/three.git
      ref: v0.1.0
  at_a_bare_version:
    git:
      url: https://example.invalid/somebody/four.git
      ref: 0.1.0
  at_no_ref:
    git:
      url: https://example.invalid/somebody/five.git
  at_inline_flow: {git: {url: https://example.invalid/somebody/six.git, ref: master}}
  at_inline_flow_pinned: {git: {url: https://example.invalid/somebody/seven.git, ref: 0.1.0-alpha-20260821194500}}
  at_a_commit:
    git:
      url: https://example.invalid/somebody/eight.git
      ref: 4f3a1c9e2b7d5086af14c3e9d2b6081fa7c45e39
  at_a_short_commit:
    git:
      url: https://example.invalid/somebody/nine.git
      ref: 4f3a1c9e2b7d
  path: ^1.9.1

dev_dependencies:
  lints: ^6.1.0
''';

/// An overrides file naming a branch, which this check must leave alone.
const String _plantedOverrides = '''
dependency_overrides:
  at_master:
    git:
      url: https://example.invalid/somebody/one.git
      ref: master
''';

/// A manifest whose every git dependency is pinned, so a reader that reported everything is caught.
const String _plantedPinnedManifest = '''
name: planted_package

dependencies:
  at_a_release_tag:
    git:
      url: https://example.invalid/somebody/pinned.git
      ref: 0.1.0-stable-20260901120000
''';
