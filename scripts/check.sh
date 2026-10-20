#!/usr/bin/env bash
# The one entry point for this repository's checks.
#
#   ./scripts/check.sh
#
# One step, and a red one stops the run: build.sh proves every half of this repository.
# Which halves there are is read off the disk there and
# not repeated here, because a second spelling of them is a second thing to keep true. This file
# exists so that every repository of this family answers to one command name, and so the push hook
# has one thing to call.
set -uo pipefail

root="$(git rev-parse --show-toplevel)" || exit 1
cd "$root" || exit 1

fail() { echo "check: FAIL — $1"; exit 1; }

echo "check: every half of this repository, analysed, formatted and tested."

# The tool is named before it is missed. build.sh starts `dart` inside a subshell per half, so on a
# machine without it the run is red with two lines of "dart: command not found" and nothing that
# says a toolchain is the reason.
command -v dart >/dev/null 2>&1 \
  || fail "dart is not on this machine, and every half is analysed, formatted and tested with it. The version this repository is true against is the constant dartVersion in gate/lib/src/pins.dart. Nothing was checked."

bash build.sh || fail "bash build.sh — a half above is red, and its output names which one."

echo "check: OK — every check green"
