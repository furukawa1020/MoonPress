from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/posts'
    code,h,row=s.request(route,'POST',{'title':'Raw content','content':{'raw':'<p>Safe <strong>bold</strong> text.</p>'}},'author')
    assert code==201 and '<strong>bold</strong>' in row['content']['rendered']
    detail=route+'/'+str(row['id']);before={p.name:p.read_bytes() for p in (s.site/'content').glob('*.md')}
    assert s.request(detail,'PATCH',{'content':{'raw':row['content']['raw']}},'author',h['ETag'])[1]['ETag']==h['ETag']
    for value in [{'raw':'<script>bad</script>'},{'raw':'<p onclick="bad">X</p>'},{'raw':7},{'rendered':'Missing'}]:
        assert s.request(detail,'PATCH',{'content':value},'author',h['ETag'])[0]==400
    assert before=={p.name:p.read_bytes() for p in (s.site/'content').glob('*.md')}
print('Raw content objects reuse safe HTML conversion and guarded byte-preserving no-op behavior.')
