"""Reject unsafe or ambiguous public inventories before returning any metadata."""
from wp_media_fixture import *
import pathlib,json,subprocess,os
with NativeSite() as s:
    assert s.request(ROUTE)[2]==[] and not (s.site/'public').exists()
    target=s.root/'outside';target.mkdir();(target/'private.png').write_bytes(b'private')
    (s.site/'public').symlink_to(target,target_is_directory=True)
    assert s.request(ROUTE)[0]==500
with MediaSite() as s:
    route=ROUTE+'/'+str(ident('alpha.png'))
    for page in [1,9]:
        code,h,rows=s.request(ROUTE+f'?offset=3&page={page}')
        assert code==200 and rows==[] and h['X-WP-Total']==h['X-WP-TotalPages']=='0'
    before={p.name:p.read_bytes() for p in (s.site/'public').iterdir()}
    target=s.root/'secret';target.write_bytes(b'private-do-not-expose')
    link=s.site/'public/link.png';link.symlink_to(target)
    for url in [ROUTE,route]:
        code,h,row=s.request(url);assert code==500 and 'private-do-not-expose' not in json.dumps(row)
    assert before=={p.name:p.read_bytes() for p in (s.site/'public').iterdir() if p.name!='link.png'}
    link.unlink();large=s.site/'public/large.png'
    with large.open('wb') as f:f.truncate(8388609)
    assert s.request(ROUTE)[0]==500;large.unlink()
    seen={};pair=None
    for i in range(200000):
        name=f'collision-{i}.png';value=ident(name)
        if value in seen:pair=(seen[value],name);break
        seen[value]=name
    assert pair
    for name in pair:(s.site/'public'/name).write_bytes(FILES['alpha.png'])
    assert s.request(ROUTE)[0]==500 and s.request(route)[0]==500
    for name in pair:(s.site/'public'/name).unlink()
    assert s.request(ROUTE)[0]==200
    for i in range(8):
        with (s.site/'public'/f'total-{i}.png').open('wb') as f:f.truncate(8388608)
    assert s.request(ROUTE)[0]==500
    for i in range(8):(s.site/'public'/f'total-{i}.png').unlink()
    for i in range(4094):(s.site/'public'/f'empty-{i}.png').write_bytes(b'')
    assert s.request(ROUTE)[0]==500
with MediaSite() as s:
    public=s.site/'public';foreign=s.root/'foreign';foreign.mkdir();(foreign/'other.png').write_bytes(b'private')
    preload=s.root/'swap.so'
    subprocess.run(['cc','-Wall','-Wextra','-Werror','-shared','-fPIC','tests/native/swap_authoring_directory.c','-ldl','-o',str(preload)],check=True)
    change={'LD_PRELOAD':str(preload),'MOONPRESS_SWAP_DIRECTORY':str(public),'MOONPRESS_SWAP_MOVED':str(s.root/'moved'),'MOONPRESS_SWAP_FOREIGN':str(foreign),'MOONPRESS_SWAP_PHASE':'lock'}
    old={key:os.environ.get(key) for key in change}
    try:
        os.environ.update(change);s.restart();code,h,rows=s.request(ROUTE)
        assert code==200 and set(names(rows))==set(FILES),(code,rows)
        assert (foreign/'other.png').read_bytes()==b'private'
    finally:
        for key,value in old.items():
            if value is None:os.environ.pop(key,None)
            else:os.environ[key]=value
print('Public media snapshot: collision, symlink, byte/count bounds, retained-directory race and no-mutation checks passed.')
