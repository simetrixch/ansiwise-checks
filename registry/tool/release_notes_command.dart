/// What the release notes of one tag are, decided over a git and the manifests the program is handed.
///
/// WHY THIS EXISTS AT ALL, and why `gh release create --generate-notes` was not enough. Generated
/// notes are built from the pull requests merged between two releases and the new contributors among
/// them. This repository has none — `gh pr list --state all` answers with nothing — so generated
/// notes would have nothing to list and the page would carry a compare link and no line about what
/// changed. A merge commit is no test of that either way, since a squashed pull request leaves none. Unique tags per release do
/// not change that: the tag grammar decides how many releases there are, not where the sentences
/// come from.
///
/// WHAT IT READS. `git tag --list` for what has been released before this one — held against the
/// same [TagFilter] read from .github/workflows/release.yml that decides everything else here —
/// `git log --format=%s <previous>..<tag>` for the commit subjects in between, and `git remote
/// get-url` for the address a caller writes when it names this tag. The job that runs it checks out
/// with `fetch-depth: 0`, because a shallow checkout has neither the tags nor the range.
///
/// WHAT IT REFUSES. A tag whose parts cannot be read, and a tag on a channel [ReleaseChannel] does
/// not rank. Both would otherwise end as a release marked by a guess: an unranked channel is not
/// knowably a pre-release, and publishing it plainly would tell everyone reading the releases page
/// that an alpha is finished.
library;

import 'release_git.dart';
import 'release_manifest.dart';
import 'release_pubspec.dart';
import 'release_report.dart';
import 'release_tag_filter.dart';
import 'release_versions.dart';

/// The notes of one release, read from the history behind its tag.
final class ReleaseNotesCommand {
  /// Asks [git] for the history, [filter] which of the tags it names are releases, and [manifests]
  /// what a caller writes to name this repository at the tag.
  const ReleaseNotesCommand({
    required this.git,
    required this.filter,
    required this.manifests,
    this.remote = 'origin',
  });

  /// The git the commands are run through.
  final Git git;

  /// Which tags are releases, as .github/workflows/release.yml states it.
  final TagFilter filter;

  /// Every package manifest of this repository, which the one tag released together.
  final List<Manifest> manifests;

  /// The remote whose address a caller writes in its own manifest.
  final String remote;

  /// The notes for [tag], or a refusal naming what could not be read.
  Future<NotesOutcome> of(String tag) async {
    if (filter.unreadable case final String why) {
      return NotesOutcome.refused(why);
    }
    if (filter.refusalFor(tag) case final String refusal) {
      return NotesOutcome.refused(refusal);
    }
    final ReleasedTag? release = ReleasedTag.read(tag);
    if (release == null) {
      return NotesOutcome.refused(
        '"$tag" is a tag $releaseWorkflowPath triggers on, and its parts could not be read as '
        '<major>.<minor>.<patch>-<channel>-<ts14> — so nothing here can say which channel it is on',
      );
    }
    final ReleaseChannel? channel = release.channel;
    if (channel == null) {
      return NotesOutcome.refused(
        '"$tag" is on the channel "${release.channelName}", which is not one of '
        '${ReleaseChannel.spelled.join(', ')} — nothing here can say whether that is a pre-release, '
        'and a release marked by a guess tells everyone reading the releases page something nobody '
        'checked. $releaseWorkflowPath and registry/tool/release_versions.dart disagree about the channels, '
        'and one of the two is wrong',
      );
    }

    final GitAnswer origin = await git.run(<String>['remote', 'get-url', remote]);
    if (!origin.isGreen || origin.lines.isEmpty) {
      return NotesOutcome.refused(
        'this checkout could not say where $remote points, and the page has to print the address a '
        'caller writes to resolve this tag — git said: ${_quoted(origin)}',
      );
    }
    final List<ReleasedPackage> packages = <ReleasedPackage>[];
    for (final Manifest manifest in manifests) {
      final String? text = manifest.text;
      final String? name = text == null ? null : declaredNameIn(text);
      if (name == null) {
        return NotesOutcome.refused(
          '${manifest.path} declares no name this page could tell a caller to write, and a release '
          'page of a repository nobody can name is a page that says nothing',
        );
      }
      packages.add(ReleasedPackage(name: name, directory: _directoryOf(manifest.path)));
    }

    final GitAnswer tags = await git.run(<String>['tag', '--list']);
    if (!tags.isGreen) {
      return NotesOutcome.refused(
        'the tags of this checkout could not be read, so what this release follows is unknown and '
        'an empty answer must not be read as a first release — git said: ${_quoted(tags)}',
      );
    }
    final ReleasedTag? previous = _theOneBefore(release, _linesOf(tags.output));

    final GitAnswer log = await git.run(<String>[
      'log',
      '--format=%s',
      if (previous == null) tag else '${previous.tag}..$tag',
    ]);
    if (!log.isGreen) {
      return NotesOutcome.refused(
        'the commits behind $tag could not be read, so the notes would say nothing changed when '
        'nobody looked — git said: ${_quoted(log)}. A checkout without `fetch-depth: 0` has neither '
        'the tags nor the range',
      );
    }

    return NotesOutcome.written(
      page: notesFor(
        release: release,
        channel: channel,
        previous: previous?.tag,
        subjects: _linesOf(log.output),
        packages: packages,
        url: origin.lines.first,
      ),
      isPreRelease: channel.isPreRelease,
    );
  }

  /// The latest release standing before [release] among [tags], or null when it is the first.
  ReleasedTag? _theOneBefore(ReleasedTag release, List<String> tags) {
    ReleasedTag? before;
    for (final ReleasedTag each in Releases.ofTags(tags, filter: filter).releases) {
      if (each.compareTo(release) < 0) {
        before = each;
      }
    }
    return before;
  }

  static String _directoryOf(String path) {
    final int cut = path.lastIndexOf('/');
    return cut < 0 ? '' : path.substring(0, cut);
  }

  static List<String> _linesOf(String output) => output
      .split('\n')
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .toList(growable: false);

  static String _quoted(GitAnswer answer) =>
      answer.lines.isEmpty ? '(nothing at all)' : answer.lines.join(' / ');
}
