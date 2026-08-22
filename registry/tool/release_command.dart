/// What the release program does, decided over a git and a set of manifests it is handed rather than
/// ones it opens inline.
///
/// Two things happen here and they are deliberately unequal. [ReleaseCommand.show] READS: it asks git
/// for the tags on the remote, for what HEAD is and for where origin points, reads every manifest of
/// this repository, and writes a screen. [ReleaseCommand.release] is the only thing in this
/// repository that WRITES to a remote, and what it pushes is a commit and one annotated tag, because
/// .github/workflows/release.yml triggers on a pushed tag and on nothing else.
///
/// THE PROGRAM'S LAST ACT IS THE PUSHED TAG. It creates no GitHub Release and writes no notes — the
/// workflow does both — so nothing here calls `gh`, and a `command -v gh` preflight would be a check
/// standing in front of a program that never runs it.
///
/// WHY A RELEASE OF THESE PACKAGES REFUSES OVER A REF, which is the thing this program does that no
/// release of a binary needs to. These packages produce no file: what a caller gets when it names a
/// tag is the TREE at that tag, and a tree whose own manifests name `master` resolves to something
/// else tomorrow under the same name. So every dependency naming THIS repository is set to the tag
/// being cut — the release can do that, because it is the tag it is composing — and every dependency
/// naming any OTHER repository at something that is no released tag REFUSES the release, because
/// this program cannot know which tag of somebody else's repository was meant and a tag that pins
/// nothing is worse than no tag at all.
///
/// WHICH HALF OF WHAT WAS TYPED IS WRONG IS ANSWERED, NOT LEFT TO THE READER. The channel is held
/// against [ReleaseChannel], which is what decides whether the release is a pre-release and is a
/// thing no glob can state. The version is held against the filter, by composing the tag and asking
/// it. Those are two questions and not two answers to one: a filter narrowed to two channels admits
/// a channel this program ranks, and a filter widened to a fourth admits one it does not, and each
/// of the two refusals names the file it came from.
///
/// A FAILED READ IS NEVER AN EMPTY REMOTE. `git ls-remote` answering non-zero and a repository with
/// no tags produce the same empty list, and one of them means "nothing has been released" while the
/// other means nothing at all — so the status is read before the output is, and a failed read
/// refuses instead of proposing a first release to somebody who already released 1.4.2.
library;

import 'release_git.dart';
import 'release_manifest.dart';
import 'release_pubspec.dart';
import 'release_report.dart';
import 'release_tag_filter.dart';
import 'release_versions.dart';

/// The release program's two acts, over a [Git] and the manifests of one repository.
final class ReleaseCommand {
  /// Asks [git], bumps every one of [manifests], holds what is typed against [filter], and works on
  /// [remote].
  ///
  /// [now] is the clock the ts14 half of the tag is stamped from, handed in so that a check can
  /// assert the tag a typed version and channel compose.
  const ReleaseCommand({
    required this.git,
    required this.manifests,
    required this.filter,
    this.now = DateTime.now,
    this.remote = 'origin',
  });

  /// The git the commands are run through.
  final Git git;

  /// Every package manifest of this repository, which one release bumps in lockstep.
  final List<Manifest> manifests;

  /// Which tags start a release, as .github/workflows/release.yml states it.
  final TagFilter filter;

  /// The clock the ts14 half of a composed tag is stamped from.
  final DateTime Function() now;

  /// The remote whose tags are the releases of these packages.
  final String remote;

  /// What has been released, what a release would name, and what could come next — changing nothing.
  Future<ReleaseOutcome> show() async {
    if (filter.unreadable case final String why) {
      return ReleaseOutcome.refused(why);
    }
    final GitAnswer tags = await git.run(<String>['ls-remote', '--tags', remote]);
    if (!tags.isGreen) {
      return ReleaseOutcome.refused(_theTagsCouldNotBeRead(tags));
    }
    final GitAnswer branch = await git.run(<String>['rev-parse', '--abbrev-ref', 'HEAD']);
    final GitAnswer commit = await git.run(<String>['rev-parse', '--short', 'HEAD']);
    if (!branch.isGreen || !commit.isGreen) {
      return ReleaseOutcome.refused(
        'this checkout could not say which commit HEAD is at, so a release could not say what it '
        'would name — git said: ${_quoted(branch.isGreen ? commit : branch)}',
      );
    }
    final (String? url, String? unreachable) = await _originUrl();
    if (url == null) {
      return ReleaseOutcome.refused(unreachable!);
    }

    final Map<String, String?> declared = <String, String?>{};
    final List<String> followed = <String>[];
    for (final Manifest manifest in manifests) {
      final String? text = manifest.text;
      declared[manifest.path] = text == null ? null : declaredVersionIn(text);
      for (final GitDependency dependency in gitDependenciesIn(text ?? '')) {
        if (dependency.url != url && !dependency.isReleased(filter)) {
          followed.add(followedAs(manifest.path, dependency));
        }
      }
    }

    return ReleaseOutcome.shown(
      listingOf(
        Releases.ofTags(tagNamesIn(tags.output), filter: filter),
        filter: filter,
        declaredVersion: _theOneDeclaredVersion(declared),
        remote: remote,
        branch: _firstLineOf(branch),
        commit: _firstLineOf(commit),
        manifests: declared,
        followed: followed,
      ),
    );
  }

  /// Bumps to [version], pins this repository to the tag, commits, tags and pushes — or refuses and
  /// touches nothing.
  ///
  /// THE ORDER OF THE REFUSALS IS THE ORDER OF WHAT THEY NEED. The leading zero is asked first
  /// because it needs no file and no clock; then the channel, which needs only the ranking; then the
  /// filter, which needs the workflow read; then git, and only then are the manifests read. Nothing
  /// is written until every one of them has passed, so a refused release leaves a tree nobody has to
  /// put back.
  Future<ReleaseOutcome> release(String version, String channelName) async {
    if (numbersRefusalFor(version) case final String refusal) {
      return ReleaseOutcome.refused(refusal);
    }
    if (filter.unreadable case final String why) {
      return ReleaseOutcome.refused(why);
    }
    final ReleaseChannel? channel = ReleaseChannel.named(channelName);
    if (channel == null) {
      return ReleaseOutcome.refused(
        '"$channelName" is no channel: a release is cut on one of '
        '${ReleaseChannel.spelled.join(', ')}, as hostyour-manager/shared/release.ts:12 states '
        'them. How ripe the channel is decides whether the release page marks this a pre-release '
        'and how far the tag may then reach, and neither is a thing to guess at',
      );
    }
    // Which half of what was typed the filter stops on, told apart by a probe that varies nothing
    // but the channel: 0.0.0 carries no leading zero and fourteen zeros are fourteen digits, so a
    // probe this filter refuses is refused for its channel and for nothing else.
    if (filter.refusalFor(tagFor(version: '0.0.0', channel: channel, at: _theProbeMoment))
        case final String refusal) {
      return ReleaseOutcome.refused(
        '$releaseWorkflowPath does not trigger on the channel "$channelName", so a release cut on '
        'it would build nothing: $refusal',
      );
    }

    final String tag = tagFor(version: version, channel: channel, at: now());
    if (filter.refusalFor(tag) case final String refusal) {
      return ReleaseOutcome.refused(
        '"$version" is no version $releaseWorkflowPath triggers on — the channel "$channelName" is '
        'one it does, so the version is what stopped it: $refusal',
      );
    }
    final GitAnswer status = await git.run(<String>['status', '--porcelain']);
    if (!status.isGreen) {
      return ReleaseOutcome.refused(
        'this checkout could not say whether it is clean, and a release cut over changes nobody '
        'listed is a tree nothing in git describes — git said: ${_quoted(status)}',
      );
    }
    if (status.lines.isNotEmpty) {
      return ReleaseOutcome.refused(
        'the working tree is not clean — commit or stash first. The tag would name a commit that '
        'does not carry these changes: ${_quoted(status)}',
      );
    }

    final GitAnswer local = await git.run(<String>[
      'rev-parse',
      '-q',
      '--verify',
      'refs/tags/$tag',
    ]);
    if (local.isGreen) {
      return ReleaseOutcome.refused(
        'the tag $tag already exists in this checkout. The ts14 half of a tag is stamped from the '
        'clock, so this is a second run inside the same second or a clock that went backwards — '
        'run it again',
      );
    }
    if (local.status != 1) {
      return ReleaseOutcome.refused(
        'this checkout could not be asked whether the tag $tag already stands in it — git said: '
        '${_quoted(local)}',
      );
    }

    final GitAnswer tags = await git.run(<String>['ls-remote', '--tags', remote]);
    if (!tags.isGreen) {
      return ReleaseOutcome.refused(_theTagsCouldNotBeRead(tags));
    }
    if (Releases.ofTags(tagNamesIn(tags.output), filter: filter).holds(tag)) {
      return ReleaseOutcome.refused(
        '$tag already stands on $remote — a second tag of one name is a release nobody could tell '
        'from the first one',
      );
    }

    final (String? url, String? unreachable) = await _originUrl();
    if (url == null) {
      return ReleaseOutcome.refused(unreachable!);
    }

    final (List<_Bump>? bumps, String? impossible) = _bumpsFor(version, tag: tag, url: url);
    if (bumps == null) {
      return ReleaseOutcome.refused(impossible!);
    }

    final String bumped = _write(bumps, version: version, tag: tag);
    final List<ReleasedPackage> packages = <ReleasedPackage>[
      for (final _Bump bump in bumps)
        ReleasedPackage(name: bump.name, directory: _directoryOf(bump.manifest.path)),
    ];

    if (bumps.any((_Bump each) => each.changed)) {
      final GitAnswer staged = await git.run(<String>['add', '--update']);
      if (!staged.isGreen) {
        return ReleaseOutcome.refused(
          '$bumped, and the change could not be staged, so nothing was committed, tagged or '
          'pushed — git said: ${_quoted(staged)}. `git checkout -- .` puts this checkout back',
        );
      }
      final GitAnswer committed = await git.run(<String>['commit', '-m', 'release: $tag']);
      if (!committed.isGreen) {
        return ReleaseOutcome.refused(
          '$bumped, and the commit was refused, so nothing was tagged or pushed — git said: '
          '${_quoted(committed)}. The change is staged in this checkout',
        );
      }
    }

    final GitAnswer tagged = await git.run(<String>['tag', '-a', tag, '-m', tag]);
    if (!tagged.isGreen) {
      return ReleaseOutcome.refused(
        'the annotated tag $tag could not be created in this checkout, so nothing was pushed — git '
        'said: ${_quoted(tagged)}. $bumped',
      );
    }
    final GitAnswer head = await git.run(<String>['push', remote, 'HEAD']);
    if (!head.isGreen) {
      return ReleaseOutcome.refused(
        '$remote refused the commit the tag names, so the tag was not pushed either — a tag naming '
        'a commit $remote does not have is a release nothing can resolve. git said: '
        '${_quoted(head)}. $bumped, and the tag stands in this checkout; `git tag -d $tag` removes '
        'it again',
      );
    }
    final GitAnswer pushed = await git.run(<String>['push', remote, 'refs/tags/$tag']);
    if (!pushed.isGreen) {
      return ReleaseOutcome.refused(
        '$remote refused the tag $tag, so no release was started — git said: ${_quoted(pushed)}. '
        'THE COMMIT IS ALREADY ON $remote and this program does not take it back: $bumped. The tag '
        'exists in this checkout; `git tag -d $tag` removes it, and running the release again '
        'stamps a new one',
      );
    }
    return ReleaseOutcome.pushed(
      tag: tag,
      remote: remote,
      url: url,
      channel: channel,
      bumped: bumped,
      packages: packages,
    );
  }

  /// Where origin points, or the reason a release cannot be decided without it.
  ///
  /// It is asked rather than assumed because it is what tells a dependency naming THIS repository —
  /// which the release pins to the tag it is cutting — from one naming somebody else's, which it
  /// refuses to guess a tag for. The comparison is made on the url EXACTLY as each file spells it:
  /// a remote written `git@github.com:…` and a manifest written `https://github.com/…` are the same
  /// repository to a person and two strings here, and a normalisation guessing they are the same
  /// would silently pin nothing. So the mismatch surfaces as a refusal over a branch ref instead.
  Future<(String?, String?)> _originUrl() async {
    final GitAnswer answer = await git.run(<String>['remote', 'get-url', remote]);
    if (!answer.isGreen || answer.lines.isEmpty) {
      return (
        null,
        'this checkout could not say where $remote points, and without it nothing here can tell a '
            'dependency on THIS repository — which a release pins to the tag it is cutting — from '
            'one on somebody else\'s. git said: ${_quoted(answer)}',
      );
    }
    return (answer.lines.first, null);
  }

  /// What each manifest would become, or the reason no release can be cut over them.
  (List<_Bump>?, String?) _bumpsFor(String version, {required String tag, required String url}) {
    if (manifests.isEmpty) {
      return (
        null,
        'no pubspec.yaml was found in this repository, so there is no package to release and a tag '
            'would name a tree nobody could resolve',
      );
    }
    final List<_Bump> bumps = <_Bump>[];
    for (final Manifest manifest in manifests) {
      final String? declared = manifest.text;
      if (declared == null) {
        return (
          null,
          'there is no ${manifest.path} in this checkout, so the version it declares could not be '
              'set to $version',
        );
      }
      final String? name = declaredNameIn(declared);
      if (name == null) {
        return (
          null,
          '${manifest.path} declares no name, so nothing here can say what a caller would write to '
              'name it at $tag',
        );
      }
      final String? bumped = pubspecWithVersion(declared, version);
      if (bumped == null) {
        return (
          null,
          '${manifest.path} declares no version, so there is nothing to set to $version — and a '
              'release whose package declares a different version than its tag is two answers to '
              'what this package is',
        );
      }
      String written = bumped;
      final List<String> pinned = <String>[];
      for (final GitDependency dependency in gitDependenciesIn(written)) {
        if (dependency.url != url) {
          if (!dependency.isReleased(filter)) {
            return (
              null,
              '${followedAs(manifest.path, dependency)}, which is no tag $releaseWorkflowPath would '
                  'have released. These packages publish no file, so the tree at $tag IS the '
                  'release — and a tree naming a branch resolves to something else tomorrow under '
                  'the same name. Pin it to a released tag of ${dependency.url} first; this program '
                  'will not guess which one was meant',
            );
          }
          continue;
        }
        if (dependency.refLine < 0) {
          return (
            null,
            '${manifest.path} names ${dependency.package} on this repository without a ref, so '
                'there is no line to set to $tag and a caller would resolve the default branch',
          );
        }
        written = pubspecWithRef(written, dependency: dependency, ref: tag);
        pinned.add(dependency.package);
      }
      bumps.add(
        _Bump(manifest: manifest, name: name, was: declared, becomes: written, pinned: pinned),
      );
    }
    return (bumps, null);
  }

  /// Writes every manifest that changed, and answers what a person is told about it.
  ///
  /// A MANIFEST ALREADY SAYING WHAT THE RELEASE WOULD SAY IS NOT AN ERROR AND IS NOT A COMMIT.
  /// `git commit` on an empty index refuses, and a commit forced through anyway would be a commit
  /// saying nothing — so what is unchanged is left alone and the tag names HEAD as it stands.
  String _write(List<_Bump> bumps, {required String version, required String tag}) {
    final List<String> changed = <String>[];
    final List<String> pinned = <String>[];
    for (final _Bump bump in bumps) {
      if (bump.changed) {
        bump.manifest.write(bump.becomes);
        changed.add(bump.manifest.path);
      }
      for (final String dependency in bump.pinned) {
        pinned.add('${bump.manifest.path} names $dependency at $tag');
      }
    }
    if (changed.isEmpty) {
      return 'every manifest here already declared $version and named this repository at $tag, so '
          'nothing was committed and $tag names HEAD as it stood';
    }
    return '${changed.join(', ')} now declare $version'
        '${pinned.isEmpty ? '' : ', and ${pinned.join(', ')}'}, committed here as "release: $tag"';
  }

  /// The version every manifest declares, or null when they do not all declare one and the same.
  ///
  /// A first release is proposed from what this repository says about itself, and two packages
  /// declaring two versions say two things — which is a screen showing both rows and proposing
  /// neither, rather than one picking whichever it read first.
  static String? _theOneDeclaredVersion(Map<String, String?> declared) {
    final Set<String?> versions = declared.values.toSet();
    return versions.length == 1 && versions.first != null ? versions.first : null;
  }

  /// The directory [path] sits in, which is the `path:` a caller writes, empty at the root.
  static String _directoryOf(String path) {
    final int cut = path.lastIndexOf('/');
    return cut < 0 ? '' : path.substring(0, cut);
  }

  String _theTagsCouldNotBeRead(GitAnswer answer) =>
      'the tags on $remote could not be read, so what has been released is unknown and an empty '
      'answer must not be read as an empty remote — git said: ${_quoted(answer)}';

  static String _quoted(GitAnswer answer) =>
      answer.lines.isEmpty ? '(nothing at all)' : answer.lines.join(' / ');

  static String _firstLineOf(GitAnswer answer) => answer.lines.isEmpty ? '' : answer.lines.first;

  /// The moment the channel probe is stamped at: fourteen digits that are beyond doubt, so that a
  /// refusal of the probe can only be about the channel.
  static final DateTime _theProbeMoment = DateTime.utc(2000);
}

/// One manifest, and what a release would make of it.
final class _Bump {
  const _Bump({
    required this.manifest,
    required this.name,
    required this.was,
    required this.becomes,
    required this.pinned,
  });

  final Manifest manifest;
  final String name;
  final String was;
  final String becomes;
  final List<String> pinned;

  bool get changed => was != becomes;
}
