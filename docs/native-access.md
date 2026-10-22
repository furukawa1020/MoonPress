# Native access foundation

This is a MoonBit-native single-site authentication foundation. It does not
protect the existing local owner CLI or operator editor from their operator.
Do not expose the editor, source tree or private vault through a proxy. A form
session token and an article version digest are not user authentication.

## Owner controls

Run `moonpress access-read SITE --json` to obtain the current revision and a
sanitized principal list. Initialize with:

```
moonpress access-change SITE absent grant alice administrator --json
```

Capture `report.secret` from this CLI JSON envelope privately. It is a generated
256-bit random secret, encoded as 64 lowercase hex characters. The access store
retains only a domain-separated, login-bound SHA-256 digest. This is suitable
for generated high-entropy credentials, not human-chosen passwords. WordPress
password hashes, login cookies and application-password formatting are not
imported or accepted. Never pass a secret as a command argument.

Subsequent changes require the exact revision from `access-read`:

```
moonpress access-change SITE REVISION grant writer author --json
moonpress access-change SITE REVISION role writer contributor --json
moonpress access-change SITE REVISION revoke writer - --json
moonpress access-change SITE REVISION rotate writer - --json
```

Reload the revision after each operation. Rotation issues a new secret and
reactivates a revoked principal; the previous credential immediately fails the
next authentication check. IDs and login names are never reused. At least one
active administrator must remain. Repeating the current role or revocation is
a no-op. An uncertain write result requires inspection; a secret lost after
successful publication can only be replaced by rotation.

## Implemented role decisions

`moonpress access-role ROLE --json` and `role_capabilities` report only the implemented subset.
The WordPress benchmark oracle checks each advertised capability against actual core roles. All five roles can
read. Contributors can edit/delete posts; authors additionally publish and
upload; editors manage others' posts and pages; administrators additionally
manage user and site options. `role_can_edit` also checks ownership, post/page
type and published-edit capability. Legacy unassigned ownership is reserved to
editors/administrators. These library decisions are not yet wired into an HTTP
content API. Capabilities do not imply an implemented endpoint or complete
WordPress role parity. Custom roles, per-user capability overrides, multisite,
human password login and account recovery are not implemented.

## Storage and threat boundary

The `.moonpress-access` directory is private mode 0700; event files are owned
by the process user, regular mode 0600 with one link. Directory-relative opens
refuse symlinks. Writers lock the vault, replay its strict bounded state and
compare the expected revision before an exclusive durable publication. The
log permits at most 256 identities and 4096 events, each at most 4096 bytes.
Unknown files, missing sequence entries, bad hashes, unknown fields, invalid
roles and invalid transitions fail closed. Record hashes chain exact bytes;
they detect corruption, not malicious rewriting or rollback by the filesystem
owner. Keep the site parent and backups private and under trusted ownership.
Restoring an old access backup can reactivate old credentials.

Every authentication replays current state under the same lock; there is no
credential cache. Valid digest comparisons perform the same 64-byte XOR/OR
loop. This is a source-level fixed-work property, not a machine-code timing
proof. Lock contention and corrupt/missing vaults raise errors that an HTTP
adapter must handle without falling back to anonymous privileged access.
This boundary has no public listener and no network throughput claim.
