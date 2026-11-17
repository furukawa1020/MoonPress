registerCommand("削除", row => {
  const next = row.nextElementSibling ?? row.previousElementSibling;
  selectBlock(next);
  row.remove();
  dirty = true;
  if (next) focusBlock(next);
});
