registerCommand("削除", row => {
  const next = row.nextElementSibling ?? row.previousElementSibling;
  rememberBlocks();
  selectBlock(next);
  row.remove();
  blocksChanged();
  dirty = true;
  if (next) focusBlock(next);
});
