from rest_fixture import NativeSite
with NativeSite() as s:
    route='/wp-json/wp/v2/posts';date='2020-02-29T03:04:05'
    code,_,row=s.request(route,'POST',{'title':'Date alias','date':date,'status':'publish'},'author')
    assert code==201 and row['date']==row['date_gmt']==date
    assert s.request(route,'POST',{'title':'Both','date':date,'date_gmt':date},'author')[0]==201
    for date in ['bad','2020-02-30T00:00:00','2020-01-01T00:00:00+09:00',None]:
        assert s.request(route,'POST',{'title':'Invalid','date':date},'author')[0]==400
    assert s.request(route,'POST',{'title':'Conflict','date':'2020-01-01T00:00:00','date_gmt':'2020-01-02T00:00:00'},'author')[0]==400
print('REST creation date alias: native UTC, leap dates, agreeing fields and conflict/boundary refusal passed.')
