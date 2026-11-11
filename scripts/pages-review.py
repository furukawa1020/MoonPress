"""Report differences between verified flat Pages bundles."""
from hashlib import sha256
from html import escape
from pathlib import Path
import sys


def inventory(root):
    return {path.name: sha256(path.read_bytes()).digest() for path in root.iterdir()}


def summary(before, after):
    changes = (
        ('追加', sorted(after.keys() - before.keys())),
        ('変更', sorted(name for name in before.keys() & after.keys() if before[name] != after[name])),
        ('削除', sorted(before.keys() - after.keys())),
    )
    lines = ['## MoonPress 公開差分', '', ' '.join(f'{label} {len(files)}件' for label, files in changes)]
    for label, files in changes:
        if not files:
            continue
        lines.extend(['', f'### {label}', '', '<pre>'])
        lines.extend(escape(name) for name in files[:100])
        lines.append('</pre>')
        if len(files) > 100:
            lines.append(f'ほか {len(files) - 100}件')
    return '\n'.join(lines) + '\n'


if __name__ == '__main__':
    print(summary(inventory(Path(sys.argv[1])), inventory(Path(sys.argv[2]))), end='')
