const textBlockTypes = ["p", "h2", "h3", "blockquote"];
function transformBlock(row, tag) {
  const source = encode(content(row));
  const sourceType = source[0]?.tag;
  if (source.length !== 1 || !textBlockTypes.includes(sourceType) || sourceType === tag) return;
  const replacement = makeBlock([{tag, children:source[0].children}]);
  rememberBlocks();
  row.replaceWith(replacement);
  selectBlock(replacement);
  focusBlock(replacement);
  dirty = true;
  blocksChanged();
}
function mountTransform() {
  const select = element("select");
  select.setAttribute("aria-label", "選択ブロックの変換先");
  for (const tag of textBlockTypes) {
    const option = element("option", blockTypes.get(tag).label);
    option.value = tag;
    select.append(option);
  }
  document.querySelector(".block-commands").append(select, button("変換", () => {
    if (selectedBlock) transformBlock(selectedBlock, select.value);
  }));
}
document.addEventListener("DOMContentLoaded", mountTransform);
