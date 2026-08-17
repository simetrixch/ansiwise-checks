/// Where the programs an audit reads its answer declarations out of stand.
///
/// **A program file is not a package's own.** It says what ONE installation deploys and in what
/// order, so it lives in that installation's repository beside the things it names; a plugin ships
/// the steps a program may name and no program at all. But the KINDS and the DEFAULTS of the answers
/// a step reads are declared nowhere else — a step reads an answer by name, and only the program
/// says whether that name holds text, a list, or a value that defaults to empty.
///
/// **So a probe that wants to plant what an installation plants has to read them.** The tree is
/// found once, here, so every package asks the same question of the same directory instead of each
/// carrying a path of its own that can drift.
///
/// **The tree is found by its SHAPE, and this library names no installation.** What is searched for
/// is the layout an installation has — [installationPrograms] below its root — and never the name of
/// one, because a name here would be a name every package that depends on this library inherits
/// without ever writing it down. Whoever has a tree the search does not reach, or more than one,
/// names it in [installationVariable] and the search does not run at all.
///
/// **Absent FAILS, and the refusal says what it looked for.** A suite that quietly skipped the
/// declarations would report green over the one thing this exists to measure, and the shape of that
/// failure is a probe planting a value no installation ever gives.
library;

import 'dart:io';

/// The environment variable that names the installation tree, overriding the search.
const String installationVariable = 'ANSIWISE_INSTALLATION';

/// Where the programs stand inside an installation tree.
const String installationPrograms = 'ansiwise/programs';

/// How far below a directory on the way up the search looks.
///
/// Two, which is what the shapes a checkout is met in cost. Zero is a suite run from inside the
/// installation itself. One is a checkout standing beside the repository the suite runs in. Two is
/// the same checkout one directory further out, which is where it stands when the checkouts are
/// grouped by the organisation that publishes them. Deeper is not searched: it buys nothing that
/// [installationVariable] does not buy exactly, and every level widens what an unrelated tree can be
/// mistaken for.
const int _searchDepth = 2;

/// The installation tree, as the environment names it or as a tree found from where the suite runs.
String get installationRoot {
  if (Platform.environment[installationVariable] case final String named) {
    if (!Directory('$named/$installationPrograms').existsSync()) {
      throw StateError(
        'no programs at $named/$installationPrograms — $installationVariable names a tree that '
        'does not hold an installation.',
      );
    }
    return named;
  }
  return installationFoundFrom(Directory.current.absolute);
}

/// The installation tree found by searching from [start] upward, or a refusal saying what was
/// looked for.
///
/// The packages that ask are not all at the same depth below the directory the checkouts share — a
/// plugin sits two directories inside its repository, a composition root only one — so the search
/// walks upward from where it starts, rather than resting on one relative path that is only true at
/// a single depth.
///
/// **The nearest directory that holds an answer decides, and TWO answers decide nothing.** A search
/// that picked one of two trees would report which programs a package agrees with without saying
/// that it chose, and the choice would move with the order a directory happens to be listed in.
///
/// The starting directory is a PARAMETER so the search can be driven over a tree a probe planted.
/// Reading it off the process would leave every one of the shapes below — the depths it reaches, the
/// two answers it refuses over — measurable only against whatever checkouts a machine happens to
/// carry, which is to say not measurable at all.
String installationFoundFrom(Directory start) {
  for (Directory above = start; ; above = above.parent) {
    final List<String> found = _installationsUnder(above);
    if (found.length == 1) {
      return found.single;
    }
    if (found.length > 1) {
      throw StateError(
        '${found.length} trees at or below ${above.path} hold $installationPrograms — '
        '${found.join(', ')} — and which of them these audits are meant to read is not something a '
        'search can decide. Set $installationVariable to the one you mean.',
      );
    }
    if (above.parent.path == above.path) {
      throw StateError(
        'no tree holding $installationPrograms was found from ${start.path} upward, searching each '
        'directory on the way and everything up to $_searchDepth directories below it — the '
        'programs of an installation live in its own repository, and these audits read that tree '
        'for the kinds and defaults its answers are declared with. Clone that repository beside '
        'this one, or set $installationVariable to where it is.',
      );
    }
  }
}

/// The directory the programs of the installation stand in, proven to be there.
String get installationProgramsRoot => '$installationRoot/$installationPrograms';

/// Every tree at [above], or up to [_searchDepth] directories below it, that holds
/// [installationPrograms], sorted so the answer does not move with the order a directory is listed
/// in.
///
/// A branch ends where it answers: what an installation keeps inside its own tree is that
/// installation's business, and descending into it would turn a fixture that has the same shape into
/// a second answer and refuse over both.
List<String> _installationsUnder(Directory above) {
  final List<String> found = <String>[];
  void look(Directory directory, int depth) {
    if (Directory('${directory.path}/$installationPrograms').existsSync()) {
      found.add(directory.path);
      return;
    }
    if (depth == _searchDepth) {
      return;
    }
    for (final Directory child in _directoriesIn(directory)) {
      look(child, depth + 1);
    }
  }

  look(above, 0);
  found.sort();
  return found;
}

/// The directories directly in [directory], and none where it cannot be listed.
///
/// The walk passes over whatever a workspace happens to stand beside, up to the root of the volume,
/// and some of that is not the process's to read. A refusal about one of those directories would
/// replace the refusal that says no installation was found, which is the one thing the caller can
/// act on. Links are not followed, so a link back into the walk is not a cycle.
List<Directory> _directoriesIn(Directory directory) {
  try {
    return <Directory>[
      for (final FileSystemEntity entry in directory.listSync(followLinks: false))
        if (entry is Directory) entry,
    ];
  } on FileSystemException {
    return const <Directory>[];
  }
}
