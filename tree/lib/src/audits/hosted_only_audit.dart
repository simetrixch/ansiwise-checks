/// The suite that drives [unhostedDependenciesIn] over this package, with the counter-probe beside it.
library;

import 'package:test/test.dart';

import '../dependency_pins.dart' show manifestName;
import '../hosted_only.dart';
import '../source_tree.dart';

/// Runs the hosted-only audit over [manifest], or over the manifest of the package this suite sits in.
///
/// WHAT IT STATES: how many dependencies were read, so a run that read none cannot be mistaken for a
/// run that found none. That distinction is the whole reason this check exists — the framework's own
/// check reports the unknown rather than assuming it clean, and this one would be worthless if it
/// did the opposite.
void auditHostedOnly({String? manifest}) {
  final String text = manifest ?? SourceTree.on(repositoryRoot()).textOf(manifestName) ?? '';

  test('the manifest is there to read', () {
    expect(
      text,
      isNotEmpty,
      reason:
          'no manifest was read, so this check measured nothing — and the framework that takes this '
          'package on its promise would be reading a green run that looked at no file',
    );
  });

  test('every dependency this package names is served by pub.dev', () {
    expect(
      unhostedDependenciesIn(text).map((UnhostedDependency each) => each.toString()),
      isEmpty,
      reason:
          'the framework takes this package as a dev dependency and gives up nothing for it, on the '
          'promise that it reaches nothing of this organisation. From over there this package is a '
          'git dependency it cannot follow, so that promise is kept HERE or nowhere',
    );
  });

  group('counter-probe', () {
    for (final (String by, String block) in <(String, String)>[
      ('git', '  ansiwise_core:\n    git:\n      url: https://example.invalid/core.git\n'),
      ('path', '  ansiwise_core:\n    path: ../ansiwise-core\n'),
      ('hosted', '  something:\n    hosted: https://example.invalid/pub\n    version: ^1.0.0\n'),
    ]) {
      test('THE PLANTED DEFECT: a dependency resolved by $by is reported', () {
        final List<UnhostedDependency> found = unhostedDependenciesIn(
          'name: probe\ndependencies:\n  path: ^1.9.1\n$block',
        );
        expect(found, hasLength(1), reason: 'this scan cannot go red on a $by dependency');
        expect(found.single.by, by);
        expect(
          found.single.toString(),
          contains(manifestName),
          reason: 'the file a person opens to fix it has to stand in the sentence',
        );
      });
    }

    test('THE PLANTED DEFECT: a dev dependency counts the same', () {
      expect(
        unhostedDependenciesIn(
          'name: probe\n'
          'dependencies:\n'
          '  path: ^1.9.1\n'
          'dev_dependencies:\n'
          '  ansiwise_core:\n'
          '    git:\n'
          '      url: https://example.invalid/core.git\n',
        ),
        hasLength(1),
        reason:
            'it is the same coupling in a different hat, and somebody cloning this package to run '
            'its own suite resolves it exactly as they resolve a dependency',
      );
    });

    test('THE PLANTED DEFECT: an override is reported, which is the quiet door', () {
      expect(
        unhostedDependenciesIn(
          'name: probe\n'
          'dependencies:\n'
          '  path: ^1.9.1\n'
          'dependency_overrides:\n'
          '  path:\n'
          '    path: ../path\n',
        ),
        hasLength(1),
      );
    });

    test('THE PLANTED INNOCENT: version constraints are what hosted looks like', () {
      expect(
        unhostedDependenciesIn(
          'name: probe\n'
          'dependencies:\n'
          '  path: ^1.9.1\n'
          '  yaml: ^3.1.3\n'
          "  test: '>=1.30.0 <2.0.0'\n"
          'dev_dependencies:\n'
          '  lints: ^6.1.0\n',
        ),
        isEmpty,
        reason: 'a scan that reported everything would pass every probe above',
      );
    });

    test('THE PLANTED INNOCENT: a key outside the dependency sections is not a dependency', () {
      expect(
        unhostedDependenciesIn(
          'name: probe\n'
          'executables:\n'
          '  probe:\n'
          '    path: bin/probe.dart\n'
          'dependencies:\n'
          '  path: ^1.9.1\n',
        ),
        isEmpty,
        reason: 'only the three dependency sections declare what this package resolves',
      );
    });
  });
}
