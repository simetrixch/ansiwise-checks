/// The manifests a release bumps, as something the release program is handed rather than files it
/// opens inline.
///
/// The same split registry/tool/release_git.dart makes: what the release program DECIDES is one thing and
/// writing a file on this operating system is another. It is what lets the deciding half be driven
/// by a check — including the half that bumps — on a machine where no manifest is edited, and what
/// was written is then readable as a value.
///
/// THE LOCKSTEP HAS SOMETHING TO WALK HERE. This repository holds two packages and no root package,
/// and one tag releases both — so a release bumps every manifest in the tree rather than one named
/// file, and a third package added tomorrow is released by the same act without an edit anywhere.
/// [pubspecsIn] is that walk, and it is a walk rather than a list for exactly that reason.
library;

import 'dart:io';

/// A file declaring the version of one package.
abstract interface class Manifest {
  /// Where it is, as a refusal names it: relative to the repository root.
  String get path;

  /// What it holds, or null when there is no such file.
  String? get text;

  /// Replaces what it holds with [text].
  void write(String text);
}

/// A pubspec.yaml, as a file of the machine the release program is running on.
final class PubspecFile implements Manifest {
  /// The manifest at [path], read and written under [repository].
  const PubspecFile({required this.repository, required this.path});

  /// The repository the path is counted from.
  final Directory repository;

  @override
  final String path;

  @override
  String? get text {
    final File file = _file;
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  @override
  void write(String text) => _file.writeAsStringSync(text);

  File get _file => File('${repository.path}/$path');
}

/// Every package manifest in [repository], in the order their paths sort.
///
/// WHAT IS NOT WALKED, and why each is named rather than matched by a pattern. `.git` is the
/// repository's own state, `.dart_tool` and `build` are what the toolchain wrote, and a manifest
/// found in any of them is a copy of somebody's dependency rather than a package of this
/// repository — bumping one would write a version into a directory the next resolve throws away.
List<Manifest> pubspecsIn(Directory repository) {
  final List<String> paths = <String>[];
  _walk(repository, '', paths);
  paths.sort();
  return <Manifest>[
    for (final String path in paths) PubspecFile(repository: repository, path: path),
  ];
}

/// Directory names that hold no package of this repository.
const Set<String> _notWalked = <String>{'.git', '.dart_tool', 'build'};

void _walk(Directory directory, String prefix, List<String> paths) {
  for (final FileSystemEntity entry in directory.listSync(followLinks: false)) {
    final String name = entry.path.split(RegExp(r'[/\\]')).last;
    if (_notWalked.contains(name)) {
      continue;
    }
    final String path = prefix.isEmpty ? name : '$prefix/$name';
    if (entry is Directory) {
      _walk(entry, path, paths);
    } else if (entry is File && name == 'pubspec.yaml') {
      paths.add(path);
    }
  }
}
