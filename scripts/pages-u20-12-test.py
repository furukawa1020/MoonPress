from pages_verification_fixture import *
with PublicFixture() as fixture:
    index=fixture.expected/'index.html';data=index.read_bytes();index.unlink()
    assert fixture.verify().returncode!=0 and fixture.requests==[]
    index.write_bytes(b'')
    assert fixture.verify().returncode!=0 and fixture.requests==[]
    index.write_bytes(data);assert fixture.verify().returncode==0
