function initialList(tag) {
  return [{tag, children:[{tag:"li", children:[{tag:"br",children:[]}]}]}];
}
registerBlock("ul", "箇条書き", () => initialList("ul"));
