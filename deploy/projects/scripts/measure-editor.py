"""Report raw and gzip sizes for the browser editor shipped in the Worker."""
import base64
import gzip
import json
from pathlib import Path

with Path("dist/server/index.js").open(encoding="utf-8") as built_worker:
    declaration = built_worker.readline()
assets = json.loads(declaration.removeprefix("const assets = ").rstrip().removesuffix(";"))
files = {
    "writer.js": assets["writer.js"].encode(),
    "block-engine.wasm": base64.b64decode(assets["block-engine.wasm"], validate=True),
    "style.css (shared)": assets["style.css"].encode(),
}
assert files["block-engine.wasm"].startswith(b"\x00asm\x01\x00\x00\x00")
for name, data in files.items():
    print(f"{name}: {len(data):,} bytes, {len(gzip.compress(data, mtime=0)):,} bytes gzip")
