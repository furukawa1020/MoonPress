from pages_verification_fixture import *
with PublicFixture() as fixture:
    for name in ['.moonpress.json','.moonpress-preview','.secret']:
        path=fixture.expected/name;path.write_text('private')
        assert fixture.verify().returncode!=0 and fixture.requests==[]
        path.unlink()
    assert fixture.verify().returncode==0
