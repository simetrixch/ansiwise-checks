/// What a person reads when they run registry/tool/release.dart, what the release page says, and the one line
/// that says what the run did.
///
/// The text is here rather than written where the work happens, so a check can assert what a person
/// sees without a git, a remote or a terminal — the screen IS half the feature, and a screen nothing
/// can read is a screen nobody can hold to anything.
///
/// THE THING BOTH TEXTS ARE BUILT AROUND: this repository publishes no file. What a caller gets when
/// it names a tag is the TREE at that tag, so what the person and the release page both have to be
/// shown is the manifest lines a caller writes — the package name, this repository's url, the tag,
/// and the directory the package sits in. [pinsFor] is that block, written once and printed in both.
library;

import 'release_pubspec.dart';
import 'release_tag_filter.dart';
import 'release_versions.dart';

/// One package of this repository, as a caller names it.
final class ReleasedPackage {
  /// The package [name] whose manifest sits in [directory], the empty string at the root.
  const ReleasedPackage({required this.name, required this.directory});

  /// The package this repository holds, as a caller names it — `ansiwise_checks`, not `registry`.
  final String name;

  /// Which directory of this repository it sits in, which is the `path:` a caller writes.
  final String directory;
}

/// The manifest lines a caller writes to name every package of this repository at [tag].
///
/// [url] is this repository as its own remote spells it, so the block a person copies is the one
/// pub will resolve rather than a second spelling of the same address.
String pinsFor(List<ReleasedPackage> packages, {required String tag, required String url}) {
  final StringBuffer block = StringBuffer();
  for (final ReleasedPackage package in packages) {
    block
      ..writeln('  ${package.name}:')
      ..writeln('    git:')
      ..writeln('      url: $url')
      ..writeln('      ref: $tag');
    if (package.directory.isNotEmpty) {
      block.writeln('      path: ${package.directory}');
    }
  }
  return block.toString();
}

/// What one invocation of the release program did.
final class ReleaseOutcome {
  /// [text] is everything the person reads, and [isGreen] whether the run did what it was asked.
  const ReleaseOutcome({required this.text, required this.isGreen});

  /// Nothing was done, and [why] says what was wrong.
  factory ReleaseOutcome.refused(String why) =>
      ReleaseOutcome(text: 'release: FAIL — $why', isGreen: false);

  /// [listing] was shown and nothing was touched.
  factory ReleaseOutcome.shown(String listing) => ReleaseOutcome(
    text:
        '$listing\n'
        'release: OK — nothing was pushed; a release starts when a version and a channel are typed',
    isGreen: true,
  );

  /// The tag [tag] was pushed to [remote], which is the whole of what starts a release.
  ///
  /// [bumped] says what happened to the versions the manifests declare, because a person who typed a
  /// version has to know what was committed in their name before the tag was put on it, and
  /// [packages] is what a caller then names at [tag].
  factory ReleaseOutcome.pushed({
    required String tag,
    required String remote,
    required String url,
    required ReleaseChannel channel,
    required String bumped,
    required List<ReleasedPackage> packages,
  }) => ReleaseOutcome(
    text:
        'release: OK — the tag $tag is on $remote, and pushing it is the whole of what starts a '
        'release\n'
        '  $bumped\n'
        '  $releaseWorkflowPath runs the gate of every package on this tag and then publishes a\n'
        '  GitHub Release named $tag carrying no file — these packages produce none, and the tree\n'
        '  at the tag is what a caller resolves,\n'
        '  ${channel.isPreRelease ? 'marked as a pre-release because ${channel.name} is not the ripest channel' : 'published plainly, because ${channel.name} is the ripest channel'}\n'
        '  gh run watch   follows it\n'
        '  THE CHANNEL IS A CEILING, NOT A DEPLOYMENT: ${channel.name} reaches ${channel.reaches}.\n'
        '  Nothing in this repository enforces that ceiling — it is enforced where deployments\n'
        '  are written (hostyour-manager/shared/release.ts:8)\n'
        '  NOBODY IS JUDGED BY IT YET: a caller runs the audits of the tag ITS OWN manifest names,\n'
        '  and this release moved no manifest but the ones in here. What a caller writes is:\n'
        '${pinsFor(packages, tag: tag, url: url)}',
    isGreen: true,
  );

  /// Everything the person reads.
  final String text;

  /// Whether the run did what it was asked.
  final bool isGreen;
}

/// What one run of the notes program produced: the page, or the reason there is none.
final class NotesOutcome {
  /// [page] is what the release page carries, and [isPreRelease] how the release is to be marked.
  const NotesOutcome.written({required this.page, required this.isPreRelease}) : refusal = null;

  /// Nothing was written, and [refusal] says what could not be read.
  const NotesOutcome.refused(this.refusal) : page = '', isPreRelease = false;

  /// What the release page carries.
  final String page;

  /// Whether the release is to be marked as a pre-release.
  final bool isPreRelease;

  /// Why there is no page, or null when there is one.
  final String? refusal;

  /// Whether the run did what it was asked.
  bool get isGreen => refusal == null;
}

/// The page a GitHub Release named by [release]'s tag carries.
///
/// [previous] is the release this one follows, or null when it is the first, [subjects] are the
/// commit subjects between the two, and [packages] at [url] are what a caller names. AN EMPTY RANGE
/// IS SAID OUT LOUD rather than left as a heading with nothing under it: a release whose tag names
/// the same commit as the last one is a real thing — the same code cut on a riper channel — and a
/// page that simply showed no changes would read as a page nobody generated.
String notesFor({
  required ReleasedTag release,
  required ReleaseChannel channel,
  required String? previous,
  required List<String> subjects,
  required List<ReleasedPackage> packages,
  required String url,
}) {
  final StringBuffer page = StringBuffer()
    ..writeln('Channel **${channel.name}** — this release may run in ${channel.reaches}.')
    ..writeln('')
    ..writeln(
      'The ceiling is enforced where deployments are written, not by this release '
      '(hostyour-manager/shared/release.ts:8).',
    )
    ..writeln('')
    ..writeln(
      'No file is attached: these packages produce none. The tree at this tag is the release, and '
      'naming it is what a caller does:',
    )
    ..writeln('')
    ..writeln('```yaml')
    ..write(pinsFor(packages, tag: release.tag, url: url))
    ..writeln('```')
    ..writeln('')
    ..writeln(
      'These audits are what a caller is JUDGED by, so the tag decides which rules it is held to. '
      'Every package of this repository is released under one tag and they may not be named apart.',
    )
    ..writeln('')
    ..writeln(
      previous == null
          ? '## Changes — every commit up to this tag, because nothing was released before it'
          : '## Changes since $previous',
    )
    ..writeln('');
  if (subjects.isEmpty) {
    page.writeln(
      previous == null
          ? 'No commit was found behind this tag, which is a history nobody could read.'
          : 'Nothing changed since $previous: this tag names the same code, cut again.',
    );
  }
  for (final String subject in subjects) {
    page.writeln('- $subject');
  }
  if (previous != null) {
    page
      ..writeln('')
      ..writeln('`git log --format=%s $previous..${release.tag}` is the range this was read from.');
  }
  return page.toString();
}

/// The screen shown when the program is run with no arguments: what the workflow releases on, what
/// has been released, what a tag would name, what this repository still follows a branch of, and
/// what could come next.
///
/// [branch] and [commit] describe what HEAD is, because the tag a release pushes names THIS commit —
/// a person deciding a version is deciding which commit becomes a release, and a screen that hid it
/// would hide half the decision. [manifests] is every package this release would bump, against the
/// version it declares today, and [followed] is every git dependency of them naming something that
/// is no released tag — the thing that stops a release before it starts.
String listingOf(
  Releases releases, {
  required TagFilter filter,
  required String? declaredVersion,
  required String remote,
  required String branch,
  required String commit,
  required Map<String, String?> manifests,
  required List<String> followed,
}) {
  final StringBuffer screen = StringBuffer()
    ..writeln('a tag starts a release when $releaseWorkflowPath triggers on it, which is:');
  for (final String pattern in filter.stated) {
    screen.writeln('  $pattern');
  }
  screen
    ..writeln('')
    ..writeln('released so far, read from the tags on $remote:');
  if (releases.releases.isEmpty) {
    screen.writeln('  nothing — no version of these packages has been released');
  } else {
    for (final ReleasedTag released in releases.releases.reversed) {
      screen.writeln('  ${released.tag}');
    }
  }
  if (releases.otherTags.isNotEmpty) {
    screen
      ..writeln('')
      ..writeln('tags on $remote this screen could not place as a release:');
    for (final String tag in releases.otherTags) {
      screen.writeln('  $tag');
    }
  }
  screen
    ..writeln('')
    ..writeln('a release would name this commit:')
    ..writeln('  $branch at $commit')
    ..writeln('')
    ..writeln('and bump every package of this repository to the version typed, in lockstep:');
  for (final MapEntry<String, String?> manifest in manifests.entries) {
    screen.writeln('  ${manifest.key.padRight(28)}declares ${manifest.value ?? 'no version'}');
  }
  screen
    ..writeln('')
    ..writeln('what these packages follow rather than pin:');
  if (followed.isEmpty) {
    screen.writeln('  nothing — every dependency names a released tag');
  }
  for (final String following in followed) {
    screen.writeln('  $following');
  }
  screen
    ..writeln('')
    ..writeln('possible next versions, none of them chosen:');
  final List<Proposal> proposals = releases.proposals(declaredVersion: declaredVersion);
  if (proposals.isEmpty) {
    screen.writeln('  none — the packages here do not all declare one and the same version');
  }
  for (final Proposal proposal in proposals) {
    screen.writeln('  ${proposal.version.padRight(16)}${proposal.because}');
  }
  screen
    ..writeln('')
    ..writeln('and the channel, which is a ceiling on where the tag may run:');
  for (final ReleaseChannel channel in ReleaseChannel.values) {
    screen.writeln('  ${channel.name.padRight(16)}reaches ${channel.reaches}');
  }
  screen
    ..writeln('')
    ..writeln('type the version and the channel you decided on:')
    ..writeln('  dart run registry/tool/release.dart <version> <channel>')
    ..writeln(
      '  dart run registry/tool/release.dart help     what a release is, and what it is not',
    );
  return screen.toString();
}

/// How one git dependency reads on the screen and in a refusal.
///
/// The manifest and the dependency are both named because three manifests naming `master` are three
/// separate things to fix, and a sentence naming only the ref would say which value is wrong without
/// saying where it is written.
String followedAs(String manifest, GitDependency dependency) =>
    '$manifest: ${dependency.package} at '
    '${dependency.ref.isEmpty ? 'no ref at all, which is the default branch' : '"${dependency.ref}"'}';

/// What `help` writes.
///
/// IT DOES NOT SPELL OUT WHICH TAGS ARE ADMITTED, and that is the point rather than a gap in this
/// text. The one place that decides is `on.push.tags` in the workflow; the program reads it every run
/// and the screen prints what it says today, so a help text carrying its own copy would be a second
/// spelling of the grammar.
const String helpText =
    '''
release — show what has been released, and start a release of a version and a channel you type.

  dart run registry/tool/release.dart                        what has been released, and what could come next
  dart run registry/tool/release.dart <version> <channel>    push the tag, which starts the release
  dart run registry/tool/release.dart help                   this

WHAT A RELEASE OF THESE PACKAGES IS. They produce no file and nobody downloads one. A caller
resolves them out of git, so a release is a TAG a caller can name, and the tree at that tag is the
whole of what it gets. ONE TAG RELEASES EVERY PACKAGE IN THIS REPOSITORY: these audits are what a
caller is judged by, the half that reads a tree and the half that drives a registry decide together,
and two packages named at two tags would hold one caller to two sets of rules.

WITH NO ARGUMENTS IT CHANGES NOTHING. It reads the tags on origin, prints what has been released,
names the commit a release would carry, lists what every manifest here declares and what any of them
still follows rather than pins, and proposes what could come next. It never picks a version: which
release a change deserves is a decision, and a program that took it would hide it.

WHAT THE TWO ARGUMENTS COMPOSE. The tag is <major>.<minor>.<patch>-<channel>-<ts14>, where the ts14
is the UTC yyyyMMddHHmmss this program stamps at the moment you run it — never typed, which is what
makes one version cut twice on one channel two tags instead of one name pushed twice. The grammar is
hostyour-manager/shared/release.ts:22, one grammar for every release of everything.

THE CHANNEL IS A CEILING ON WHERE THE TAG MAY RUN — alpha reaches dev, beta reaches dev and test, stable
reaches everywhere — and NOTHING HERE ENFORCES IT. It is enforced where deployments are written
(hostyour-manager/shared/release.ts:8). What the channel decides here is only whether the release
page marks the release as a pre-release.

WHICH TAGS ARE ADMITTED IS NOT WRITTEN IN THIS PROGRAM. $releaseWorkflowPath triggers on
`on.push.tags` and on nothing else, so a tag that filter does not match starts nothing — no gate and
no release. The filter is read out of that file on every run and the composed tag is held against it;
run with no arguments to see what it states today. The one thing this program refuses that the filter
cannot is a leading zero in a number, because a filter pattern has no alternation and `01.2.3` is no
version.

WHAT HAPPENS WHEN YOU TYPE THEM. The working tree has to be clean. Every pubspec.yaml in this
repository has its version set to the one you typed. EVERY DEPENDENCY NAMING THIS REPOSITORY IS SET
TO THE TAG BEING CUT, because a package that names its neighbour at `master` is a tag that pins
nothing — a caller resolving it tomorrow gets a different tree under the same name. Any OTHER
dependency still naming a branch REFUSES the release, for the same reason and because this program
cannot know which tag of somebody else's repository was meant. That bump is committed, then an
ANNOTATED tag is created, HEAD is pushed and the tag is pushed, and that is all that happens here.

WHAT DOES NOT HAPPEN. No release is created here — the workflow runs every package's gate on the tag,
creates the release, writes its notes and marks a pre-release. And nobody is judged by the new audits:
a caller runs the tag ITS OWN manifest names, and moving that is an act in the caller's repository.
''';
