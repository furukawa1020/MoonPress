function registerCommand(label, run) { blockCommands.set(label, run); }
function moveBlock(row, step) {
  if (!engine) return;
  const items = blocks();
  const current = items.indexOf(row);
  const destination = engine.movement_index(items.length, current, step);
  if (destination === -1) return;
  rememberBlocks();
  body.insertBefore(row, step === 1 ? items[destination].nextSibling : items[destination]);
  dirty = true;
  blocksChanged();
  selectBlock(row);
  focusBlock(row);
}
registerCommand("上へ", row => moveBlock(row, -1));
registerCommand("下へ", row => moveBlock(row, 1));

function mountCommands() {
  const buttons = element("div");
  buttons.className = "block-commands";
  buttons.setAttribute("aria-label", "選択したブロックの操作");
  for (const [label, run] of blockCommands) {
    buttons.append(button(label, () => { if (selectedBlock) run(selectedBlock); }));
  }
  body.before(buttons);
  blockMounted.push(() => { buttons.hidden = !blockEditor; });
  buttons.hidden = !blockEditor;
}
document.addEventListener("DOMContentLoaded", mountCommands);
