from pages_preview_fixture import *
with source() as root:
    secret=root/'site/content/private.md'
    secret.write_text('---\n{"title":"Private","draft":true}\n---\nPrivate text')
    cli('build',root/'site',root/'preview','--include-drafts')
    marker=root/'preview/.moonpress-preview'
    assert marker.is_file()
    assert (root/'preview/private.html').is_file()
    assert 'written: 0' in cli('build',root/'site',root/'preview','--include-drafts').stdout
    cli('build',root/'site',root/'preview')
    assert not marker.exists() and not (root/'preview/private.html').exists()
    cli('build',root/'site',root/'clean')
    assert {p.name:p.read_bytes() for p in (root/'preview').iterdir()}=={p.name:p.read_bytes() for p in (root/'clean').iterdir()}
print('Preview marker tracks inclusion and disappears on a production rebuild.')
