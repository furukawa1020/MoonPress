#!/usr/bin/env bash
set -euo pipefail
mkdir -p dist/server dist/.openai
cp .openai/hosting.json dist/.openai/hosting.json
moon_home="${MOON_HOME:-$HOME/.moon}"
if [[ ! -f "$moon_home/lib/core/_build/wasm/release/bundle/prelude/prelude.mi" ]]; then
  moon -C "$moon_home/lib/core" bundle --target wasm --release
fi
moon -C block_engine build --target wasm --release
python3 - <<'PY'
from pathlib import Path
from base64 import b64encode
import json
assets = {name: Path('worker', name).read_text() for name in ('writer.js', 'style.css')}
assets['writer.js'] += '\n' + '\n'.join(path.read_text() for path in sorted(Path('worker/blocks').glob('*.js')))
assets['block-engine.wasm'] = b64encode(Path('block_engine/_build/wasm/release/build/moonpress-block-engine.wasm').read_bytes()).decode('ascii')
assets['dotgothic16.woff'] = b64encode(Path('worker/fonts/dotgothic16.woff').read_bytes()).decode('ascii')
assets['font-license.txt'] = Path('worker/fonts/font-license.txt').read_text()
Path('dist/server/index.js').write_text('const assets = ' + json.dumps(assets) + ';\n' + Path('worker/index.js').read_text())
PY
