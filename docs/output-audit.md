# Output integrity audit

`audit_output` inspects an existing MoonPress-managed directory without source
input. It uses the compiler's manifest parser and shared output lock. Missing,
malformed, unsupported or non-regular manifests fail the operation; unowned
output is not assumed to be a valid empty build.

Findings are sorted by output name. Tracked files are `intact`, `missing`,
`edited`, `unsafe` (not a regular file) or `unreadable`. Digest findings include
expected and actual SHA-256. Foreign entries and `.moonpress-stage` remnants are
reported without reading their contents. Symlinks and special entries are not
followed. `healthy` is true only when every finding is intact.

This stricter audit reports missing files even though a normal build can
regenerate them. It never repairs, deletes or creates files. A staging finding
is not proof that recovery is possible; use the documented recovery procedure
only with verifiable journal state. Unsupported remnants remain a release gate.

The lock coordinates current MoonPress writers, not external editors or hostile
path replacement. Results describe the files observed during inspection and do
not reserve them for deployment. Digests and the manifest detect divergence,
not authenticity: an attacker able to rewrite both can forge ownership state.
No crash recovery or power-loss guarantee is added by this audit.

## CLI

Run `moonpress audit <output-directory> [--json]`. Healthy reports exit 0.
Reports with findings exit 1 **and retain their complete stdout report**; this is
an intentional exception to the usual CLI failure channel. Schema-1 JSON wraps
`healthy` and `findings`; consumers should inspect statuses rather than assuming
all exit-1 cases are parse failures. Operation errors (invalid/missing manifest,
invalid output directory) exit 1 with stderr and empty stdout. Argument errors
exit 2. Auditing neither builds nor deploys and has no draft mode.
