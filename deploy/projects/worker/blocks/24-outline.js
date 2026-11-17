function mountOutline() {
  const outline = element("details");
  outline.className = "block-outline";
  const heading = element("summary", "ブロック一覧");
  const list = element("ol");
  outline.append(heading, list);
  const refresh = () => {
    if (!blockEditor) return;
    const rows = blocks();
    heading.textContent = "ブロック一覧 (" + rows.length + ")";
    list.replaceChildren(...rows.map((row, index) => {
      const entry = element("li");
      const type = content(row).firstElementChild?.localName;
      const label = blockTypes.get(type)?.label ?? "本文";
      entry.append(button((index + 1) + ". " + label, () => { selectBlock(row); focusBlock(row); }));
      return entry;
    }));
  };
  blockMounted.push(() => { outline.hidden = !blockEditor; refresh(); });
  blockObservers.push(refresh);
  outline.hidden = !blockEditor;
  body.before(outline);
  refresh();
}
document.addEventListener("DOMContentLoaded", mountOutline);
