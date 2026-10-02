#!/usr/bin/env bash
# =============================================================================
# build.sh — prove every half of this repository locally, the way
# .github/workflows/checks.yml does.
# =============================================================================
#
# THIS REPOSITORY BUILDS NOTHING. It holds the criteria every gate judges by, is
# imported from test files and from no library file at all, and is a passive part
# of ansiwise-cli with no release of its own. "Building" it means proving it.
#
# THE HALVES ARE RUN APART, because that is how they stand: `tree` judges a source
# tree, `registry` judges a step registry, `gate` runs a repository's own tools,
# and each carries its own manifest. The two that need `tree` name it by PATH —
# they sit in one checkout, which is why they cannot fall out of step with it.
#
# WHICH HALVES THERE ARE IS READ OFF THE DISK. A list written here would have to
# be edited by whoever adds a half, in a file they have no reason to open, and a
# half left out of it is a half this run reports nothing about while saying every
# one is green.
#
# Windows entry point: build.ps1 in this folder. It is a shim that starts
# THIS file, so there is no second spelling of this build to keep true.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

failed=0
for manifest in */pubspec.yaml; do
  half="${manifest%/pubspec.yaml}"
  echo "build: $half"
  (
    cd "$half"
    dart pub get >/dev/null
    dart analyze --fatal-infos
    dart format --output=none --set-exit-if-changed .
    dart test
  ) || failed=1
done
test "$failed" -eq 0 || { echo "build: FAIL — a half above is red" >&2; exit 1; }
echo "build: OK — every half of this repository is green"
