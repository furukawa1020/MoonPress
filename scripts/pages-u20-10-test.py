from pages_verification_fixture import *
with PublicFixture() as fixture:
    empty=fixture.root/'empty';empty.mkdir()
    link=fixture.root/'linked';link.symlink_to(fixture.expected,target_is_directory=True)
    for path in [fixture.root/'missing',fixture.expected/'index.html',empty,link]:
        result=fixture.verify(bundle=path)
        assert result.returncode!=0 and fixture.requests==[],(path,result.stderr)
    assert fixture.verify().returncode==0
