"""Exercise operator edits through real HTML forms and the native comment log."""
import html
import re
import sys

from operator_fixture import Operator
from rest_fixture import NativeSite

stage = int(sys.argv[1]) if len(sys.argv) > 1 else 4


def snapshot(site):
    return {p.name: p.read_bytes() for p in (site / '.moonpress-comments').iterdir()}


with NativeSite() as site:
    code, _, post = site.request('/wp-json/wp/v2/posts', 'POST', {
        'title': 'Operator editing', 'status': 'publish',
    }, 'author')
    assert code == 201
    route = '/wp-json/moonpress/v1/comments'
    code, _, row = site.request(route, 'POST', {
        'post': post['id'], 'content': '\n\n<script>Original</script>',
        'author_name': 'Reader',
    }, 'subscriber')
    assert code == 201
    detail = route + '/' + str(row['id']) + '?context=edit'
    with Operator(site.site) as operator:
        original = snapshot(site.site)
        code, page = operator.request('/comment?id=' + str(row['id']))
        assert code == 200
        form = re.search(r'<form method="post" action="/comment-edit">(.*?)</form>', page, re.S)[1]
        assert '&lt;script&gt;Original&lt;/script&gt;' in form
        assert 'maxlength="8192">\n\n\n&lt;script&gt;' in form
        fields = dict(re.findall(r'name="(token|id|revision)" value="([^"]*)"', form))
        fields['content'] = 'Edited\r\nsecond line'
        if stage >= 2:
            fields['author_name'] = ' New reader '
        if stage >= 3:
            fields['status'] = 'approved'
        assert original == snapshot(site.site)
        assert operator.request('/comment-edit', 'POST', {**fields, 'token': 'bad'})[0] == 400
        assert operator.request('/comment-edit', 'POST', fields, {'Origin': 'https://other.example'})[0] == 400
        assert operator.request('/comment-edit', 'POST', {**fields, 'unexpected': 'x'})[0] == 400
        assert original == snapshot(site.site)
        for text in ['', 'x' * 8193, 'あ' * 2731]:
            assert operator.request('/comment-edit', 'POST', {**fields, 'content': text})[0] == 400
        if stage >= 2:
            for name in ['', 'x' * 81, 'A\tB']:
                assert operator.request('/comment-edit', 'POST', {**fields, 'author_name': name})[0] == 400
        if stage >= 3:
            assert operator.request('/comment-edit', 'POST', {**fields, 'status': 'trash'})[0] == 400
        assert original == snapshot(site.site)
        code, page = operator.request('/comment-edit', 'POST', fields)
        assert code == 200 and 'Comment saved.' in page
        code, headers, changed = site.request(detail, role='editor')
        assert code == 200 and changed['content']['raw'] == 'Edited\nsecond line'
        if stage >= 2:
            assert changed['author_name'] == 'New reader'
        if stage >= 3:
            assert changed['status'] == 'approved'
        saved = snapshot(site.site)
        assert len(saved) == len(original) + 1
        stale_text = '\n\n</textarea><script>Keep my draft</script>'
        code, failure = operator.request('/comment-edit', 'POST', {**fields, 'content': stale_text})
        assert code == 412 and saved == snapshot(site.site)
        if stage >= 4:
            assert html.escape(stale_text, quote=True) in failure
            assert '<script>' not in failure and 'action="/comment-edit"' not in failure
            assert '<textarea readonly>\n\n\n&lt;/textarea&gt;' in failure
        current = {**fields, 'revision': headers['ETag'].strip('"')}
        assert operator.request('/comment-edit', 'POST', current)[0] == 200
        assert saved == snapshot(site.site)
        # Trashing invalidates the edit form and cannot be bypassed by a POST.
        moderation = {
            'token': fields['token'], 'id': fields['id'],
            'revision': current['revision'], 'status': 'trash',
        }
        assert operator.request('/comment-status', 'POST', moderation)[0] == 200
        trashed = snapshot(site.site)
        assert 'action="/comment-edit"' not in operator.request('/comment?id=' + fields['id'])[1]
        current_tag = site.request(detail, role='editor')[1]['ETag'].strip('"')
        assert operator.request('/comment-edit', 'POST', {**current, 'revision': current_tag})[0] == 409
        assert trashed == snapshot(site.site)
    site.restart()
    restored = site.request(detail, role='editor')[2]
    assert restored['content']['raw'] == 'Edited\nsecond line'
print('Operator editing: guarded writes, atomic fields, no-op, conflict, private trash and restart checks passed.')
