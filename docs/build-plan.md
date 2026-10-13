# Detailed incremental planning

`inspect_build_plan(site, output, include_drafts=false)` returns the actual
compiler plan under the same shared output lock and ownership validation used by
`compile_site(..., dry_run=true)`. It never publishes files or creates directories.

`summary` is the existing `BuildReport`, including events, changes and counts.
`outputs` gives each planned `write`, `keep` or `delete`, its actual first reason,
optional old/new content digests and every added/changed/removed dependency.
Output and dependency rows have deterministic name order. Unchanged outputs are
included. A missing owned file may require `write` with equal old/new digests and
no dependency changes: repairing missing output is distinct from source changes.

New outputs have no old digest and removed outputs have no new digest. This
plans current sources against the recorded output, not hypothetical future edits.
Manually changed files, foreign entries, symlinks and pending journals are refused
before reporting. Use `recover` for supported journaled interrupted publication.
Sources and output must stay stable between a plan and a later build; the plan is
an observation, not a reservation or a publication authorization token.
