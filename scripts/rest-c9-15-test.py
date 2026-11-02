from embed_fixture import *
with NativeSite() as s:
    p=post(s,moonpress_categories=['Category'],moonpress_tags=['Tag']);url=P+'/'+str(p['id'])
    code,h,row=s.request(url+'?_embed=wp:term&_fields=id,_embedded.wp:term')
    assert code==200 and set(row)=={'id','_embedded'} and row['_embedded']['wp:term'][1][0]['name']=='Tag'
    assert s.request(url+'?_embed=author&_fields=id')[2]=={'id':p['id']}
    assert s.request(url+'?_embed=author&_fields=_embedded.author.0.id')[2]=={'_embedded':{'author':[{'id':s.ids['author']}]}}
