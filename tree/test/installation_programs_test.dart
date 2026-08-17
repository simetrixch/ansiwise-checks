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
/// WHAT IS NOT PROVEN HERE, and it is the one shape a planted tree cannot carry: the refusal when
/// there is no installation at all. That answer is only reached after the walk has passed every
/// directory up to the root of the volume, and what stands up there belongs to the machine rather
/// than to this suite — a probe asserting it would pass here and fail on a machine that keeps a
/// checkout in the home directory. The environment override is the other one: it is read from the
/// process, which a test in the same process cannot set.
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
}
