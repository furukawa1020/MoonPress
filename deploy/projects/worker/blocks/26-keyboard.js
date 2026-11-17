body.addEventListener("keydown", event => {
  if (!blockEditor || !selectedBlock || !event.altKey || !event.shiftKey || event.ctrlKey || event.metaKey) return;
  if (event.key === "ArrowUp" || event.key === "ArrowDown") {
    event.preventDefault();
    moveBlock(selectedBlock, event.key === "ArrowUp" ? -1 : 1);
  }
});
document.addEventListener("DOMContentLoaded", () => {
  const commands = document.querySelector(".block-commands");
  const up = commands.querySelector("button");
  up.setAttribute("aria-keyshortcuts", "Alt+Shift+ArrowUp");
  up.title = "Alt+Shift+↑";
  up.nextElementSibling.setAttribute("aria-keyshortcuts", "Alt+Shift+ArrowDown");
  up.nextElementSibling.title = "Alt+Shift+↓";
});
