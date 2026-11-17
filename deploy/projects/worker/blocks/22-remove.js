registerCommand("削除", row => {
  if (!engine) return;
  const previous = blocks();
  const selection = engine.selection_after_removal(previous.length, previous.indexOf(row));
  rememberBlocks();
  row.remove();
  const next = blocks()[selection] ?? null;
  selectBlock(next);
  blocksChanged();
  dirty = true;
  if (next) focusBlock(next);
});
