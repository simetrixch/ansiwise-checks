import 'dart:convert';
import 'dart:io';

import 'package:ansiwise_checks_gate/ansiwise_checks_gate.dart';
import 'package:test/test.dart';

/// ci-tools — the Dart that ci-tools.json names is the Dart the gate is pinned to.
///
/// The master's ci installs the tools this repository's ci-tools.json names before it runs
/// scripts/check.sh, and the gate refuses every SDK but [dartVersion]. A pin raised without the file
/// leaves the ci installing a Dart the gate then refuses on every push, so the two are held together
/// here, where the pin is written.
void main() {
  /// What is wrong with [ciTools] as the Dart file of a repository pinned to [pinned], or null.
  String? drift(String ciTools, String pinned) {
    final Object? parsed = jsonDecode(ciTools);
    if (parsed is! Map<String, Object?>) {
      return 'is not an object of tools and versions';
    }
    if (parsed.length != 1 || parsed['dart'] != pinned) {
      return 'names $parsed and not {dart: $pinned}';
    }
    return null;
  }

  test('the Dart that ci-tools.json names is the pinned one, and it names no other tool', () {
    final File file = File('../ci-tools.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'ci-tools.json stands at the root of this repository',
    );
    expect(drift(file.readAsStringSync(), dartVersion), isNull);
  });

  test('another Dart, another tool, an extra tool and a file that is no object are caught', () {
    expect(drift('{"dart": "$dartVersion"}', dartVersion), isNull, reason: 'the innocent case');
    expect(drift('{"dart": "3.12.0"}', dartVersion), isNotNull, reason: 'a Dart the gate refuses');
    expect(drift('{"go": "1.24.13"}', dartVersion), isNotNull, reason: 'no Dart at all');
    expect(
      drift('{"dart": "$dartVersion", "go": "1.24.13"}', dartVersion),
      isNotNull,
      reason: 'a tool no check of this repository runs',
    );
    expect(drift('["dart"]', dartVersion), isNotNull);
  });
}
