from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    table='<thead><tr><th>Name</th><th>Value</th></tr></thead><tbody><tr><td>A</td><td><strong>B</strong></td></tr></tbody>'
    expected=None
    for attrs,css in [('', ' class="has-fixed-layout"'),(' {"hasFixedLayout":false}',''),(' {"hasFixedLayout":true}',' class="has-fixed-layout"')]:
        content='<!-- wp:table'+attrs+' --><figure class="wp-block-table"><table'+css+'>'+table+'</table></figure><!-- /wp:table -->'
        code,h,row=s.request(route,'POST',dict(title='Table',content=content),'author')
        assert code==201,(code,row)
        if expected is None:expected=row['content']['rendered']
        assert row['content']['rendered']==expected and '<th scope="col">Name</th>' in expected
    detail=route+'/'+str(row['id']);before={p.name:p.read_bytes() for p in (s.site/'content').glob('*.md')}
    bad=['<!-- wp:table {"hasFixedLayout":"yes"} --><figure><table>'+table+'</table></figure><!-- /wp:table -->', '<!-- wp:table --><figure onclick="bad"><table>'+table+'</table></figure><!-- /wp:table -->','<!-- wp:table --><figure><table>'+table+'</table><figcaption>Lost</figcaption></figure><!-- /wp:table -->','<!-- wp:table {"hasFixedLayout":false} --><figure><table class="has-fixed-layout">'+table+'</table></figure><!-- /wp:table -->']
    for content in bad:assert s.request(detail,'PATCH',dict(content=content),'author',h['ETag'])[0]==400
    assert before=={p.name:p.read_bytes() for p in (s.site/'content').glob('*.md')}
print('Gutenberg core/table intake: static header/body tables, validated layout wrappers and no-mutation rejection passed.')
