# History and recoverable trash

Save the current editor before navigating or changing separate metadata forms.
From an article, **Inspect and restore history** opens a read-only inventory.
Enable history explicitly; it retains content before subsequent changed saves.
Checkpoint preserves the current version on demand. Inspect a revision, compare
it with current source, then restore the reviewed version. A stale current
SHA-256 refuses restoration. Restoring also retains the version it replaces.
Identical article bytes are one distinct version, not a complete event log.

**Review moving saved article to trash** shows the exact current version and
links to reference inspection. Moving stores a durable private backup before
unlinking the live source. From **Trash**, inspect a record and restore it to its
original unoccupied filename. The restored source uses owner-only mode 0600;
permissions are not widened to a typical 0644 umask. Existing articles are never
overwritten. Acknowledged **permanent purge** deletes only the reviewed record
with its exact record hash. It cannot be undone and does not purge revisions.

These actions never build or deploy output. Existing published files remain
until a separately reviewed build/deployment. Broken references may stop that
build; inspect references before removing sources. Keep an independent source
backup. Private `.moonpress-history` and `.moonpress-trash` directories are not
compiler inputs, public assets, or static export content. Each record accepts
at most 4 MiB source/16 MiB encoded JSON, with at most 4096 entries per vault.
Exceeding a bound or encountering invalid records stops the operation rather
than silently discarding versions. There is no automatic retention/pruning yet.

CLI: `history-enable`, `history`, `checkpoint`, `revision`, `compare-revision`,
`restore-revision`, `trash-post`, `trash-list`, `trash-read`, `trash-restore`, and
`trash-purge`. Each accepts `--help`; mutation commands require inspected hashes.
Permanent purge additionally requires the literal `confirm-permanent`.

## 日本語での操作

記事を保存してから「履歴を確認・復元する」へ移動し、「履歴を有効にする」を
押します。以後の変更前の内容を保存します。過去に失った編集や、ブラウザで
まだ保存していない入力は復元できません。版を確認し、現在との差分を見てから
復元します。ゴミ箱も保存済みの記事が対象です。復元先のファイル名が使用中なら
上書きしません。完全削除は確認した保管データだけを消す、元に戻せない操作です。
履歴・ゴミ箱の操作だけで、公開先の内容は変更されません。
