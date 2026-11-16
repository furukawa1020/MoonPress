"""Save a reviewed update to the tracked Pages configuration."""

import json
from pathlib import Path
import subprocess
import tempfile


def update_settings(cli, site, git, edit):
    path = site / 'site.json'
    git('ls-files', '--error-unmatch', '--', str(path), stdout=subprocess.DEVNULL)
    snapshot = json.loads(subprocess.check_output(
        [cli, 'settings-read', site, '--json'],
    ))['report']
    settings = json.loads(snapshot['content'])
    if not edit(settings):
        return []
    with tempfile.TemporaryDirectory() as temp:
        replacement = Path(temp) / 'site.json'
        replacement.write_text(json.dumps(settings, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        subprocess.check_output([
            cli, 'settings-save', site, snapshot['digest'], replacement, '--json',
        ])
    return [path]
