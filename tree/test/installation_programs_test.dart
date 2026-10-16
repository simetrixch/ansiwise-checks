import 'dart:io';

import 'package:ansiwise_checks_tree/ansiwise_checks_tree.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The search that finds the installation tree, driven over trees this file plants.
///
/// WHY IT IS PLANTED AND NOT READ OFF THIS MACHINE. Every audit that reads an installation's answer
/// declarations is pointed at whatever this search answers, so a search that reached the wrong tree
/// would have all of them measuring programs nobody asked about and reporting green over it. A probe
/// that needed one particular checkout to be on the disk would prove that on one machine and nothing
/// on the next, so each shape below is a directory tree written for it.
///
/// A case whose answer is only reached at the end of the walk stops the walk at a directory of its
/// own. Without the stop the walk climbs into the machine's temporary directory, where another run's
/// planted tree can stand, and the case would read that tree. Each such case plants one there, so a
/// walk that climbed past its stop answers with it and goes red.
///
/// WHAT IS NOT PROVEN HERE: the environment override. It is read from the process, which a test in
/// the same process cannot set.
void main() {
  late Directory workspace;

  setUp(() {
    // Under the system temporary directory rather than beside the repository, so nothing the search
    // walks past belongs to this checkout.
    workspace = Directory.systemTemp.createTempSync('installation-search');
    addTearDown(() => workspace.deleteSync(recursive: true));
  });

  Directory planted(String path) =>
      Directory('${workspace.path}/$path')..createSync(recursive: true);

  /// A tree at [path] carrying the layout an installation has.
  Directory installationAt(String path) {
    planted('$path/$installationPrograms');
    return Directory('${workspace.path}/$path');
  }

  /// [path] with the separators this platform writes.
  ///
  /// The answer comes back built out of what the file system listed, so its separators are the
  /// platform's, while a path planted above is written with `/` on every platform. Without this the
  /// two would be the same tree spelled two ways and compare as different.
  String asWritten(String path) => p.normalize(path);

  test('a suite running inside the installation finds it where it stands', () {
    final Directory installation = installationAt('checkout');

    expect(asWritten(installationFoundFrom(installation)), asWritten(installation.path));
  });

  test('a checkout standing beside the repository the suite runs in is found', () {
    // The shape the refusal tells whoever has no installation to make: clone it beside this one.
    final Directory installation = installationAt('checkout');

    expect(
      asWritten(installationFoundFrom(planted('repository/lib/src'))),
      asWritten(installation.path),
    );
  });

  test('a checkout one directory further out is found, where a group of checkouts puts it', () {
    // The shape a workspace has when the checkouts are grouped by whoever publishes them, which is
    // two directories below the one the groups share.
    final Directory installation = installationAt('group-b/checkout');

    expect(
      asWritten(installationFoundFrom(planted('group-a/repository'))),
      asWritten(installation.path),
    );
  });

  test('a tree without the layout is passed over, however it is named', () {
    // The search reads the layout and never a name, so a directory that merely stands where an
    // installation could stand is not one.
    planted('group-a/checkout');
    final Directory installation = installationAt('group-b/checkout');

    expect(
      asWritten(installationFoundFrom(planted('group-a/repository'))),
      asWritten(installation.path),
    );
  });

  test('the nearer answer decides, and the farther one is never reached', () {
    final Directory near = installationAt('group-a/checkout');
    installationAt('group-b/checkout');

    expect(
      asWritten(installationFoundFrom(planted('group-a/repository'))),
      asWritten(near.path),
      reason:
          'both trees hold the layout, and the one the walk meets first is the one the suite is '
          'standing in the middle of',
    );
  });

  test('what an installation keeps inside itself is not a second answer', () {
    // A branch ends where it answers. Without that, an installation carrying a fixture of the same
    // shape would be read as two installations and refused over — and a tree may keep whatever it
    // likes inside itself.
    final Directory installation = installationAt('group-a/checkout');
    installationAt('group-a/checkout/fixture');

    expect(
      asWritten(installationFoundFrom(planted('group-a/repository'))),
      asWritten(installation.path),
    );
  });

  test('two trees under the same directory are refused, and both are named', () {
    final Directory one = installationAt('group-b/checkout');
    final Directory other = installationAt('group-c/checkout');

    expect(
      () => installationFoundFrom(planted('group-a/repository')),
      throwsA(
        isA<StateError>()
            .having(
              (StateError refused) => refused.message,
              'message',
              contains(asWritten(one.path)),
            )
            .having(
              (StateError refused) => refused.message,
              'message',
              contains(asWritten(other.path)),
            )
            // Reading one of the two would be a choice nobody made, reported as a fact, and it
            // would move with the order a directory happens to be listed in.
            .having(
              (StateError refused) => refused.message,
              'message',
              contains(installationVariable),
            ),
      ),
    );
  });

  /// The shape a folder of checkouts has while several pieces of work run at once: the clone of each
  /// repository beside `.worktrees`, and below it a directory per repository holding the linked
  /// worktrees of that repository's open work.
  group('a folder that keeps linked worktrees beside its clones', () {
    late Directory folder;

    setUp(() {
      folder = planted('folder');
      // Another run's tree, beside the folder the walk stops at.
      installationAt('another-run/checkout');
    });

    /// A linked worktree of the installation at [path], as git writes one: its `.git` is a file.
    Directory linkedWorktreeAt(String path) {
      final Directory worktree = installationAt(path);
      File('${worktree.path}/.git').writeAsStringSync(
        'gitdir: ${folder.path}/installation/.git/worktrees/${p.basename(path)}\n',
      );
      return worktree;
    }

    /// A linked worktree of the installation, in the directory `.worktrees` keeps for it.
    Directory worktreeAt(String name) => linkedWorktreeAt('folder/.worktrees/installation/$name');

    /// The clone of the installation beside `.worktrees`: its `.git` is a directory.
    Directory cloneAt() {
      planted('folder/installation/.git');
      return installationAt('folder/installation');
    }

    /// Where the suite of another repository runs: inside a linked worktree of that repository.
    Directory suiteStart() => planted('folder/.worktrees/repository/issue/lib');

    String foundFrom(Directory start) => asWritten(installationFoundFrom(start, upTo: folder));

    test('the clone is read over two worktrees found nearer', () {
      worktreeAt('issue-a');
      worktreeAt('issue-b');
      final Directory clone = cloneAt();

      expect(foundFrom(suiteStart()), asWritten(clone.path));
    });

    test('the clone is read over one worktree found nearer', () {
      worktreeAt('issue-a');
      final Directory clone = cloneAt();

      expect(
        foundFrom(suiteStart()),
        asWritten(clone.path),
        reason: 'the worktree is a branch another piece of work has checked out',
      );
    });

    test('two worktrees and no clone are refused, and the variable that resolves it is named', () {
      final Directory one = worktreeAt('issue-a');
      final Directory other = worktreeAt('issue-b');

      expect(
        () => foundFrom(suiteStart()),
        throwsA(
          isA<StateError>()
              .having(
                (StateError refused) => refused.message,
                'message',
                contains(asWritten(one.path)),
              )
              .having(
                (StateError refused) => refused.message,
                'message',
                contains(asWritten(other.path)),
              )
              .having(
                (StateError refused) => refused.message,
                'message',
                contains(installationVariable),
              ),
        ),
      );
    });

    test('one worktree and no clone is read', () {
      final Directory worktree = worktreeAt('issue-a');

      expect(foundFrom(suiteStart()), asWritten(worktree.path));
    });

    test('the worktrees met first are kept, and a farther one is never reached', () {
      final Directory near = worktreeAt('issue-a');
      linkedWorktreeAt('folder/elsewhere/issue-b');

      expect(foundFrom(suiteStart()), asWritten(near.path));
    });

    test('a suite running inside a worktree of the installation reads that worktree', () {
      final Directory worktree = worktreeAt('issue-a');
      worktreeAt('issue-b');
      cloneAt();

      expect(
        foundFrom(planted('folder/.worktrees/installation/issue-a/lib')),
        asWritten(worktree.path),
      );
    });

    test('a folder without any tree is refused at the directory the walk stops at', () {
      expect(
        () => foundFrom(suiteStart()),
        throwsA(
          isA<StateError>().having(
            (StateError refused) => refused.message,
            'message',
            contains('no tree holding $installationPrograms was found'),
          ),
        ),
      );
    });
  });
}
