/// The path arithmetic the release programs do for themselves.
///
/// `package:path` would answer all of this, and nothing under tool/ may import it. A release is cut
/// on a checkout where the packages need not be resolved yet, and a `package:` import would make
/// the program unable to start until something had already resolved it. So tool/ imports nothing but
/// `dart:`, and the two things it needs from a path library are here.
///
/// THE PACKAGE IS NOT THE REPOSITORY HERE, and that is why the second of the two exists. This
/// repository holds two packages and no root package, so a program sitting in one of them has to
/// walk up to find the tree a release is cut from — the workflow that decides which tags start one,
/// and every manifest a release bumps, are above the package this program lives in.
library;

import 'dart:io';

/// The package a program under `tool/` is part of.
///
/// Taken from where the program's own file sits rather than from the working directory, so the
/// program answers the same from anywhere in the tree. [script] is `Platform.script`; it is a
/// parameter rather than read here so that what this resolves to can be asserted.
Directory packageOfToolScript(Uri script) => File.fromUri(script).parent.parent.absolute;

/// The repository [start] sits in: the nearest directory at or above it holding `.git`.
///
/// Throws [StateError] when there is no `.git` at or above [start], because then there is no
/// repository to release and every answer this program could give would be about something else.
Directory repositoryOf(Directory start) {
  Directory directory = start.absolute;
  while (true) {
    if (Directory('${directory.path}/.git').existsSync() ||
        File('${directory.path}/.git').existsSync()) {
      return directory;
    }
    final Directory parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError(
        'no .git at or above ${start.path}, so there is no repository here to release and a run '
        'would report about a tree nobody named',
      );
    }
    directory = parent;
  }
}
