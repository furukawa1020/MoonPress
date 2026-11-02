from embed_fixture import *
with NativeSite() as s:
    for kind,role in [('posts','author'),('pages','editor')]:
        p=post(s,kind=kind,role=role);links=p['_links']
        assert links['author'][0]['embeddable'] and links['replies'][0]['embeddable']
        if kind=='posts':assert all(v['embeddable'] for v in links['wp:term'])
        assert 'embeddable' not in links['self'][0]
