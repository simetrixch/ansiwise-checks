#!/usr/bin/env bash
# =============================================================================
# build.sh — prove both halves of this repository locally, the way
# .github/workflows/checks.yml does.
# =============================================================================
#
# THIS REPOSITORY BUILDS NOTHING. It holds the criteria every gate judges by, is
# imported from test files and from no library file at all, and is a passive part
# of ansiwise-cli with no release of its own. "Building" it means proving it.
#
# THE TWO HALVES ARE RUN APART, because that is how they stand: `tree` judges a
# source tree, `registry` judges a step registry, and each carries its own
# manifest. `registry` names `tree` by PATH — they sit in one checkout, which is
# why the pair cannot fall out of step with itself.
#
# Windows entry point: build.ps1 in this folder. It is a shim that starts
# THIS file, so there is no second spelling of this build to keep true.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

failed=0
for half in tree registry; do
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
echo "build: OK — both halves of this repository are green"
