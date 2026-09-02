#!/usr/bin/env pwsh
# The one entry point for this repository's checks.
#
#   ./scripts/check.ps1
#
# One step, and a red one stops the run: build.ps1 proves both halves of this repository, `tree` and
# `registry`, in the order .github/workflows/checks.yml proves them. The order and the two halves
# are written down there and not repeated here, because a second spelling of them is a second thing
# to keep true. This file exists so that every repository of this family answers to one command
# name.
#
# Bash twin: check.sh beside this file. The two are held to answering identically.
$ErrorActionPreference = "Continue"

# Both encodings are set, and they are two different things. $OutputEncoding is what PowerShell
# sends to a native command; [Console]::OutputEncoding is what the console draws. Only the second
# one puts the em dash of the verdict line on the screen — with the console left on the machine's
# code page, "check: OK — every check green" comes out with the dash replaced, and the twins then
# answer differently on the one line a reader looks at.
$OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$Root = (git rev-parse --show-toplevel)
if (-not $Root) { exit 1 }
Set-Location $Root

function Fail($message) { Write-Host "check: FAIL — $message"; exit 1 }

Write-Host "check: both halves of this repository, analysed, formatted and tested."

# The tools are named before they are missed. build.ps1 starts `dart` per half, so on a machine
# without it the run is red with lines about a command not found and nothing that says a toolchain
# is the reason.
if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
  Fail "dart is not on this machine, and both halves are analysed, formatted and tested with it. The version this repository is true against is the constant dartVersion in ../ansiwise-core/tool/gate/pins.dart. Nothing was checked."
}
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
  Fail "PowerShell 7 (pwsh) is not on this machine, and build.ps1 is started in a process of its own. Nothing was checked."
}

# build.ps1 is started as its own process rather than called in this one. A script that is called
# leaves $LASTEXITCODE holding whatever its last native command set, so a half that failed and a
# half that passed can end on the same number; a process exits once, with one code, and that code
# is the verdict.
& pwsh -NoProfile -File ./build.ps1
if ($LASTEXITCODE -ne 0) { Fail "./build.ps1 — a half above is red, and its output names which one." }

Write-Host "check: OK — every check green"
