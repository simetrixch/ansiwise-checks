import 'package:ansiwise_checks_tree/audits.dart';

/// tool-purity — this package names its tools and never an application of them.
///
/// The tools of this package are the Dart toolchain, YAML and a tree of files on disk, and it may
/// know what each of them calls its own things. What it may never know is any one product checked
/// with them: the organisation that builds it, the path of its repository, the words it gave its own
/// entities.
///
/// A name here is worse than the same name anywhere else, and that is why this file exists. The word
/// scan every other package runs LIVES in this package, so a product name that lands in it is
/// inherited by every package that depends on it without any of them writing it down, and no scan
/// outside this repository reads these files.
///
/// So the scan reads every byte of [scanned] — code, comment and fixture alike — against the word
/// list at [wordList]. The test that decides a word stands at the head of that list: could a vendor
/// with the same tools and a completely different product still use this package with that word in
/// it?
///
/// tool/ is not scanned, and that is the harness rather than a loophole. This check has to name the
/// words it forbids in order to search for them, and nothing under tool/ is compiled into the
/// package or shipped with it. It is also why the list is a file there rather than a constant here:
/// a list written into a scanned file would be an occurrence of every word on it.
void main() => auditWordPurity(
  wordListPath: wordList,
  scannedPaths: scanned,
  theRule: 'this package names no application of its tools',
);

/// Where the words this package may not name live, relative to the package root.
const String wordList = 'tool/tool-purity.words';

/// The directories of this package that are read to the byte.
///
/// Named one at a time rather than as "the package minus its tools", so adding a directory to the
/// scan is a decision somebody makes here rather than a silent widening.
const List<String> scanned = <String>['lib', 'test'];
