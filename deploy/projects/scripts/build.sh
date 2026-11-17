#!/usr/bin/env bash
set -euo pipefail
mkdir -p dist/server dist/.openai
cp .openai/hosting.json dist/.openai/hosting.json
python3 - <<'PY'
from pathlib import Path
from base64 import b64encode
import json
assets = {name: Path('worker', name).read_text() for name in ('writer.js', 'style.css')}
assets['writer.js'] += '\n' + '\n'.join(path.read_text() for path in sorted(Path('worker/blocks').glob('*.js')))
assets['dotgothic16.woff'] = b64encode(Path('worker/fonts/dotgothic16.woff').read_bytes()).decode('ascii')
assets['font-license.txt'] = Path('worker/fonts/font-license.txt').read_text()
Path('dist/server/index.js').write_text('const assets = ' + json.dumps(assets) + ';\n' + Path('worker/index.js').read_text())
PY
