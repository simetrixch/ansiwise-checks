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
