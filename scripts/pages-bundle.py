"""Inspect the expected public bundle before publication verification."""
import json,pathlib,sys
try:
    root=pathlib.Path(sys.argv[1])
    if root.is_symlink() or not root.is_dir():
        raise ValueError('Expected a regular bundle directory.')
    entries=sorted(root.iterdir(),key=lambda entry:entry.name)
    if not entries:
        raise ValueError('Expected a nonempty public bundle.')
    print(json.dumps([entry.name for entry in entries]))
except (OSError,ValueError,IndexError) as error:
    raise SystemExit(str(error))
