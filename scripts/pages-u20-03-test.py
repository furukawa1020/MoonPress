from pages_preview_fixture import *
with source() as root:
    script('prepare-pages.sh',root/'public',root/'current',root/'site')
    (root/'site/style.css').write_text('body { color: red; }')
    script('prepare-pages.sh',root/'public',root/'stale',root/'site',ok=False)
    assert not (root/'stale').exists()
    cli('build',root/'site',root/'public')
    script('prepare-pages.sh',root/'public',root/'rebuilt',root/'site')
    # A preview made by an older compiler may lack the new marker.
    (root/'site/content/private.md').write_text('---\n{"draft":true}\n---\nPrivate')
    cli('build',root/'site',root/'preview','--include-drafts')
    # Remove marker and its manifest entry to simulate the legacy artifact inventory.
    import json
    marker=root/'preview/.moonpress-preview';marker.unlink()
    path=root/'preview/.moonpress.json';manifest=json.loads(path.read_text())
    manifest['artifacts']=[a for a in manifest['artifacts'] if a['name']!='.moonpress-preview']
    path.write_text(json.dumps(manifest)+'\n')
    script('prepare-pages.sh',root/'preview',root/'legacy',root/'site',ok=False)
    assert not (root/'legacy').exists()
