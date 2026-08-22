/// The release of this repository, as a surface a person decides on.
///
/// ```
/// dart run registry/tool/release.dart                        what has been released, and what could come next
/// dart run registry/tool/release.dart <version> <channel>    push the tag they compose, which starts it
/// dart run registry/tool/release.dart help                   what a release is, and what it is not
/// ```
///
/// It never picks a version. Run with no arguments it reads the tags on origin, shows what has been
/// released, names the commit a release would carry and PROPOSES what could come next — and pushes
/// nothing. The version and the channel are then typed by hand, which is the whole point: which
/// release a change deserves and how ripe it is are decisions, and a program that took them would
/// hide them.
///
/// ONE TAG RELEASES THE WHOLE REPOSITORY. There is no root package here and there is no root
/// program either: this file sits in one package and works on the tree above it, because what a
/// release names is the repository — every pubspec.yaml under it is bumped in lockstep, and a
/// package added tomorrow is released by the same act without an edit. It lives in a package rather
/// than at the root because only the two package trees are analysed and formatted by anything: a
/// program above them both would be judged by no check at all.
///
/// WHAT IT DOES WHEN THEY ARE TYPED. It composes the tag
/// `<major>.<minor>.<patch>-<channel>-<ts14>` — the grammar of hostyour-manager/shared/release.ts:22,
/// with the ts14 stamped from the clock at that moment — refuses unless the working tree is clean,
/// the tag stands nowhere yet and no manifest here follows a branch of somebody else's repository,
/// sets every version and every ref naming THIS repository, commits that, creates an ANNOTATED tag,
/// and pushes HEAD and then the tag. THAT IS ITS LAST ACT. The GitHub Release, its notes and the
/// pre-release marking are .github/workflows/release.yml's work, which is why nothing here needs
/// `gh`.
///
/// WHICH TAGS ARE ADMITTED IS READ, NOT RESTATED. The workflow's `on.push.tags` is the only thing
/// that decides whether a tag starts anything, so it is read out of that file on every run —
/// registry/tool/release_tag_filter.dart — and this program carries no admission grammar of its own. What is
/// decided is in registry/tool/release_command.dart, the parts a tag is made of are in
/// registry/tool/release_versions.dart, what a manifest says and how it is rewritten is in
/// registry/tool/release_pubspec.dart, what a person reads is in registry/tool/release_report.dart, git is reached
/// through registry/tool/release_git.dart and the manifests through registry/tool/release_manifest.dart. This is the
/// composition root: the arguments, the real git, the real files, and the status a person's shell
/// reads.
library;

import 'dart:io';

import 'paths.dart';
import 'release_command.dart';
import 'release_git.dart';
import 'release_manifest.dart';
import 'release_report.dart';
import 'release_tag_filter.dart';

/// Shows or starts a release, and answers non-zero when nothing was done.
Future<void> main(List<String> arguments) async {
  if (arguments case <String>['help' || '--help' || '-h']) {
    stdout.writeln(helpText);
    return;
  }
  if (arguments.length == 1 || arguments.length > 2) {
    stderr.writeln(
      'release: FAIL — ${arguments.length} arguments were given, and this program takes either '
      'none, or the two a release is decided by: a version and a channel. `help` says what each is',
    );
    exit(2);
  }

  final Directory repository = repositoryOf(packageOfToolScript(Platform.script));
  final File workflow = File('${repository.path}/$releaseWorkflowPath');
  if (!workflow.existsSync()) {
    stderr.writeln(
      'release: FAIL — ${workflow.path} is not in this checkout, so nothing here can say which tag '
      'starts a release',
    );
    exit(1);
  }

  final ReleaseCommand command = ReleaseCommand(
    git: const GitOnThisMachine(),
    manifests: pubspecsIn(repository),
    filter: TagFilter.ofWorkflow(workflow.readAsStringSync()),
  );

  final ReleaseOutcome outcome = arguments.isEmpty
      ? await command.show()
      : await command.release(arguments.first, arguments.last);

  (outcome.isGreen ? stdout : stderr).writeln(outcome.text);
  exitCode = outcome.isGreen ? 0 : 1;
}
