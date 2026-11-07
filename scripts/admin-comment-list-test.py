"""Filter, navigate and inspect a disposable operator comment inventory."""
import html
import re
import sys
import urllib.parse

from comment_fixture import set_status
from operator_fixture import Operator
from rest_fixture import NativeSite

stage = int(sys.argv[1]) if len(sys.argv) > 1 else 20


def ids(page):
    table = re.search(r'<tbody>(.*?)</tbody>', page, re.S)[1]
    return [int(value) for value in re.findall(r'<tr><td><a href="/comment\?id=(\d+)"', table)]


with NativeSite() as site:
    posts = '/wp-json/wp/v2/posts'
    _, _, first = site.request(posts, 'POST', {
        'title': 'First & article', 'slug': 'first', 'status': 'publish',
    }, 'author')
    _, _, second = site.request(posts, 'POST', {
        'title': 'Second article', 'slug': 'second', 'status': 'publish',
    }, 'author')
    comments = '/wp-json/moonpress/v1/comments'

    def create(post, text, role='subscriber', parent=0):
        code, _, row = site.request(comments, 'POST', {
            'post': post['id'], 'content': text, 'author_name': 'Reader', 'parent': parent,
        }, role)
        assert code == 201
        return row

    root = create(first, 'needle first')
    set_status(site, root['id'], 'approved')
    other = create(second, 'needle second')
    author = create(first, 'needle author', 'author')
    reply = create(first, 'needle reply', parent=root['id'])
    for number in range(12):
        create(first, 'bulk ' + str(number))
    before = {p.name: p.read_bytes() for p in (site.site / '.moonpress-comments').iterdir()}
    with Operator(site.site) as operator:
        def get(query='status=any', language='en'):
            code, page = operator.request('/comments?' + query, headers={'Accept-Language': language})
            assert code == 200, (code, page)
            return page

        assert ids(get('status=any&post=' + str(second['id']))) == [other['id']]
        assert ids(get('status=any&post=&search=needle')) == [root['id'], other['id'], author['id'], reply['id']]
        for value in ['0', '-1', 'bad', '2147483648']:
            assert operator.request('/comments?post=' + value)[0] == 400
        if stage >= 6:
            page = get('status=any&post=' + str(first['id']) + '&author=' + str(site.ids['author']))
            assert ids(page) == [author['id']]
            assert 'name="author"' in page
            assert operator.request('/comments?author=bad')[0] == 400
            assert ids(get('status=any&author=')) == list(range(1, 11))
        if stage >= 7:
            assert ids(get('status=any&order=desc')) == list(range(16, 6, -1))
            assert ids(get('status=any&order=asc')) == list(range(1, 11))
            assert operator.request('/comments?order=other')[0] == 400
        if stage >= 8:
            page = get('status=any&per_page=3&page=2')
            assert ids(page) == [4, 5, 6] and 'name="per_page"' in page
            for value in ['0', '101', 'bad']:
                assert operator.request('/comments?per_page=' + value)[0] == 400
            assert operator.request('/comments?status=any&per_page=3&page=7')[0] == 400
        if stage >= 9:
            query = {'status': 'any', 'post': str(first['id']), 'author': str(site.ids['subscriber']),
                     'parent': '0', 'search': 'needle', 'order': 'desc', 'per_page': '1'}
            page = get(urllib.parse.urlencode(query))
            links = [urllib.parse.parse_qs(urllib.parse.urlsplit(html.unescape(link)).query)
                     for link in re.findall(r'href="(/comments\?[^"]+)"', page)]
            hold = next(link for link in links if link.get('status') == ['hold'])
            for key, value in query.items():
                if key != 'status':
                    assert hold.get(key) == [value], (key, hold)
            assert hold.get('page') == ['1']
        if stage >= 10:
            page = get('status=any&post=' + str(second['id']) + '&search=needle')
            assert 'hold (1)' in page and 'approved (0)' in page
        if stage >= 11:
            page = get()
            assert 'First &amp; article' in page and 'href="/edit?name=first.md"' in page
            broken = site.site / 'content/broken.md'
            broken.write_text('---\n{bad json}\n---\n# broken')
            unavailable = get()
            assert 'Article unavailable' in unavailable and ids(unavailable) == list(range(1, 11))
            broken.unlink()
        if stage >= 12:
            assert re.search(r'<time datetime="\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ">', get())
        if stage >= 13:
            code, page = operator.request('/comment?id=' + str(reply['id']))
            assert code == 200 and '>Thread root (' + str(root['id']) + ')</a>' in page
        if stage >= 14:
            assert '>1 direct replies (all statuses)</a>' in get()
            assert ids(get('status=any&parent=' + str(root['id']))) == [reply['id']]
        if stage >= 15:
            assert 'Showing 4–6 of 16 comments' in get('status=any&per_page=3&page=2')
            assert 'Showing 0–0 of 0 comments' in get('status=spam')
        if stage >= 16:
            assert re.search(r'<a href="[^"]*status=spam[^"]*" aria-current="page">', get('status=spam'))
        if stage >= 17:
            page = get('search=unmatched-query')
            assert 'No comments match these filters.' in page and 'href="/comments?status=any"' in page
        if stage >= 18:
            page = get('status=hold', 'ja')
            assert '<th>表示名</th>' in page and '<th>Author</th>' not in page and '保留' in page
        if stage >= 19:
            assert '<form method="get" action="/comment">' in get()
            for value in ['0', '-1', '1.5', 'bad']:
                assert operator.request('/comment?id=' + value)[0] == 400
            assert operator.request('/comment?id=1&extra=x')[0] == 400
        if stage >= 20:
            page = operator.request('/comment?id=' + str(root['id']))[1]
            assert 'href="/rooms/build"' in page and 'href="/rooms/publish"' in page
            assert page.index('action="/comment-edit"') < page.index('Thread root')
            assert '<details>' in get()
    assert before == {p.name: p.read_bytes() for p in (site.site / '.moonpress-comments').iterdir()}
print('Operator inventory: scoped filtering, ordering, pagination, context, threads, language and read-only navigation passed.')
