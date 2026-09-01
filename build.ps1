<#
.SYNOPSIS
  build.ps1 — prove both halves of this repository locally, the way
  .github/workflows/checks.yml does. Bash twin: build.sh in this folder. The two are held to
  answering identically.

.DESCRIPTION
  THIS REPOSITORY BUILDS NOTHING. It holds the criteria every gate judges by, is imported from test
  files and from no library file at all, and is a passive part of ansiwise-cli with no release of
  its own. "Building" it means proving it.

  THE TWO HALVES ARE RUN APART, because that is how they stand: `tree` judges a source tree,
  `registry` judges a step registry, and each carries its own manifest.
#>
$ErrorActionPreference = 'Continue'
Set-Location (git rev-parse --show-toplevel)

$failed = $false
foreach ($half in @('tree', 'registry')) {
  Write-Host "build: $half"
  Push-Location $half
  dart pub get | Out-Null
  dart analyze --fatal-infos; if ($LASTEXITCODE -ne 0) { $failed = $true }
  dart format --output=none --set-exit-if-changed .; if ($LASTEXITCODE -ne 0) { $failed = $true }
  dart test; if ($LASTEXITCODE -ne 0) { $failed = $true }
  Pop-Location
}
if ($failed) { Write-Error 'build: FAIL — a half above is red'; exit 1 }
Write-Host 'build: OK — both halves of this repository are green'
