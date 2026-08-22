/// What a release reads out of a pubspec.yaml and writes back into it: the version the package
/// declares, and the ref every git dependency of it names.
///
/// TWO THINGS ARE WRITTEN AND THEY ARE NOT THE SAME KIND OF THING. The version is what this
/// repository says about itself and is bumped in lockstep across every package here. A ref is what
/// this repository says about somebody ELSE'S code, and it is the whole reason a tag of a library is
/// worth anything: these packages produce no file, so what a caller gets when it names a tag is the
/// TREE at that tag — and a tree whose own manifests name `master` resolves to something different
/// tomorrow. A tag like that pins nothing and only looks as though it did.
///
/// READ AS LINES rather than as YAML, because everything under tool/ imports nothing but `dart:`: a
/// release is cut on a checkout where no package need be resolved, and `package:yaml` would make
/// this program unable to start until something had already resolved it. What is walked is the
/// two levels a manifest writes a dependency in — the name at one indent, the `url:` and `ref:`
/// under it at a deeper one — and a file that carries none answers with nothing, which the caller
/// turns into a refusal rather than into a release that pinned nothing.
library;

import 'release_tag_filter.dart';

/// The version [pubspec] declares this package at, or null when it declares none.
///
/// It is READ rather than restated for the same reason the tag filter is: the manifest is where a
/// package states its own version, and a first release proposed from a number typed elsewhere as
/// well would be two statements of one thing.
String? declaredVersionIn(String pubspec) => _declaredVersion.firstMatch(pubspec)?.group(1)?.trim();

/// [pubspec] with the version it declares set to [version], or null when it declares none.
///
/// WHAT IS WRITTEN IS THE THREE NUMBERS AND NOT THE TAG. The release surface takes a version and a
/// channel and never a whole tag — hostyour-manager/shared/release.ts:47 — and the version offered
/// as the first release is read straight back out of here, so a manifest carrying
/// `0.1.0-alpha-20260821194500` would propose a string nobody types as a version.
String? pubspecWithVersion(String pubspec, String version) => _declaredVersion.hasMatch(pubspec)
    ? pubspec.replaceFirst(_declaredVersion, 'version: $version')
    : null;

final RegExp _declaredVersion = RegExp(r'^version:[ \t]*(\S+)[ \t]*$', multiLine: true);

/// The name [pubspec] declares the package by, or null when it declares none.
///
/// It is the name a CALLER writes in its own manifest, and it is read from the file rather than
/// derived from the directory because the two differ by design — the directory is `registry` and
/// the package is `ansiwise_checks`.
String? declaredNameIn(String pubspec) => _declaredName.firstMatch(pubspec)?.group(1)?.trim();

final RegExp _declaredName = RegExp(r'^name:[ \t]*(\S+)[ \t]*$', multiLine: true);

/// One dependency a manifest names at a git url and a ref.
final class GitDependency {
  /// The dependency called [package] is named at [url] and [ref], written on line [refLine].
  const GitDependency({
    required this.package,
    required this.url,
    required this.ref,
    required this.refLine,
  });

  /// The name the manifest gives the dependency.
  final String package;

  /// The repository it is fetched from, spelled exactly as the manifest spells it.
  final String url;

  /// What is fetched from it: a tag under the release grammar, or a branch somebody is following.
  final String ref;

  /// Which line of the manifest the `ref:` stands on, counted from zero.
  ///
  /// Carried so that [pubspecWithRef] writes over the one line this was read from, rather than the
  /// first line anywhere in the file that happens to look the same — three dependencies naming
  /// `master` are three identical lines.
  final int refLine;

  /// Whether this names a tag [filter] would have released, rather than a branch.
  bool isReleased(TagFilter filter) => filter.accepts(ref);
}

/// Every dependency of [pubspec] named at a git url and a ref, in the order the file lists them.
///
/// A dependency without a `ref:` is not answered here: pub then follows the repository's default
/// branch, which is the same thing as naming one, and the caller has to see it. So a git dependency
/// is reported with the ref it states and, when it states none, with the empty string — which no
/// filter accepts, and which is therefore refused wherever a released ref is required.
List<GitDependency> gitDependenciesIn(String pubspec) {
  final List<String> lines = pubspec.split('\n');
  final List<GitDependency> dependencies = <GitDependency>[];
  String? package;
  String? url;
  String? ref;
  int refLine = -1;
  int nameIndent = -1;

  void flush() {
    if (package != null && url != null) {
      dependencies.add(
        GitDependency(package: package!, url: url!, ref: ref ?? '', refLine: refLine),
      );
    }
    package = null;
    url = null;
    ref = null;
    refLine = -1;
  }

  for (int index = 0; index < lines.length; index++) {
    final String line = lines[index];
    final String content = line.trimLeft();
    if (content.isEmpty || content.startsWith('#')) {
      continue;
    }
    final int indent = line.length - content.length;
    if (package != null && indent <= nameIndent) {
      flush();
    }
    if (package == null) {
      final RegExpMatch? named = _dependencyName.firstMatch(content);
      if (named != null && indent > 0) {
        package = named.group(1);
        nameIndent = indent;
      }
      continue;
    }
    final RegExpMatch? valued = _keyAndValue.firstMatch(content);
    if (valued == null) {
      continue;
    }
    switch (valued.group(1)) {
      case 'url':
        url = unquoted(valued.group(2)!.trim());
      case 'ref':
        ref = unquoted(valued.group(2)!.trim());
        refLine = index;
    }
  }
  flush();
  return dependencies;
}

/// [pubspec] with the ref on [dependency]'s own line set to [ref].
///
/// The line's indentation is kept as the file wrote it, so a manifest that is rewritten is a
/// manifest with one value changed and not one reformatted underneath its author.
String pubspecWithRef(String pubspec, {required GitDependency dependency, required String ref}) {
  final List<String> lines = pubspec.split('\n');
  final String line = lines[dependency.refLine];
  final String indent = line.substring(0, line.length - line.trimLeft().length);
  lines[dependency.refLine] = '${indent}ref: $ref';
  return lines.join('\n');
}

/// A dependency name at the head of its block: `ansiwise_core:` with nothing behind the colon.
///
/// A dependency written as one line — `path: ^1.9.1` — carries its value behind the colon and is no
/// git dependency, so it ends the block rather than opening one.
final RegExp _dependencyName = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*):\s*$');

/// A key and its value, as the lines under a git dependency write them.
final RegExp _keyAndValue = RegExp(r'^([A-Za-z_]+):[ \t]+(\S.*)$');
