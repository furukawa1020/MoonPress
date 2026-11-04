from pages_verification_fixture import *
with PublicFixture() as fixture:
    for suffix in ['?x=1','#part','?','#']:
        result=fixture.verify(fixture.url+suffix)
        assert result.returncode==2 and fixture.requests==[]
    assert fixture.verify().returncode==0
