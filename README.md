# ansiwise-checks

The audits every ansiwise repository runs on itself.

Two packages. `registry/` holds the checks and the list of them; `tree/` holds the ones that judge a
whole source tree. A repository of this family names both as dev dependencies and runs them as its
gate, so one rule is written once and applied everywhere rather than restated per repository.

`registry/checks.yaml` is the list, and it exists because `dart test` cannot be trusted to notice an
absence: delete a check file and nothing fails — the check is simply not there, and the run reports
that every check is green. Worse than a missing test, because a check and its counter-probe live in
the same file, so the thing that would have noticed goes with the thing it was watching. The suite is
told what it checks rather than asking the disk, and one test holds the disk against that list.

Nothing here ships. It judges the tree beside it and produces no file.

`bash build.sh` proves every half of this repository on a machine, in the order the ci runs it.

The ci is the master's Tekton pipeline `ansiwise-checks-ci` (hostyour-cloud
`clusters/inventories/consumer-build/templates/pipeline-ci.yaml`). On a push of the default branch or
of a branch whose name starts with `ci/` (the Trigger `github-ci-push`, hostyour-cloud
`clusters/inventories/image-builder/templates/triggers/github-ci-push.yaml`) it installs the Dart that
`ci-tools.json` names and runs `scripts/check.sh`. `gate/test/checks/ci_tools_test.dart` holds that Dart
equal to `dartVersion` in `gate/lib/src/pins.dart`. Its runs are the PipelineRuns `ansiwise-checks-ci-*`
in the namespace `ansiwise-checks-build`, and it sets the commit status `tekton/ci`.
