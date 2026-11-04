from pages_preview_fixture import *
with source() as root:
    (root/'site/content/private.md').write_text('---\n{"title":"Private","draft":true}\n---\nPrivate')
    cli('build',root/'site',root/'preview','--include-drafts')
    result=script('prepare-pages.sh',root/'preview',root/'refused',ok=False)
    assert 'Preview output cannot be published' in result.stderr and not (root/'refused').exists()
    script('prepare-pages.sh',root/'public',root/'accepted')
    assert not (root/'accepted/private.html').exists()
    (root/'site/public').mkdir()
    (root/'site/public/.private.json').write_text('{}')
    cli('build',root/'site',root/'with-internal')
    script('prepare-pages.sh',root/'with-internal',root/'refused-internal',ok=False)
    assert not (root/'refused-internal').exists()
