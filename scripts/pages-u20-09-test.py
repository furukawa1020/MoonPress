from pages_verification_fixture import *
with PublicFixture() as fixture:
    url=fixture.url.replace('http://','http://name:secret@')
    result=fixture.verify(url)
    assert result.returncode!=0 and fixture.requests==[] and 'secret' not in result.stdout+result.stderr
    assert fixture.verify().returncode==0
