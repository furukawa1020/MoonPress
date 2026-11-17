const undoBlocks = [];
const redoBlocks = [];

function rememberBlocks() {
  undoBlocks.push({rows:blocks(), selected:selectedBlock});
  if (undoBlocks.length > 50) undoBlocks.shift();
  redoBlocks.length = 0;
}
function replayBlocks(from, to) {
  const entry = from.pop();
  if (!entry) return;
  to.push({rows:blocks(), selected:selectedBlock});
  body.replaceChildren(...entry.rows);
  selectBlock(entry.selected);
  if (entry.selected) focusBlock(entry.selected);
  dirty = true;
  blocksChanged();
}
function mountBlockHistory() {
  const commands = document.querySelector(".block-commands");
  commands.append(button("構造を元に戻す", () => replayBlocks(undoBlocks, redoBlocks)),
    button("構造をやり直す", () => replayBlocks(redoBlocks, undoBlocks)));
  blockMounted.push(() => { undoBlocks.length = redoBlocks.length = 0; });
}
document.addEventListener("DOMContentLoaded", mountBlockHistory);
