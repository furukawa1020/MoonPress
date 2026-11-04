from pages_verification_fixture import *
with PublicFixture() as fixture:
    def edit(name):
        fixture.callback=None
        (fixture.expected/'index.html').write_text('edited during request')
    fixture.callback=edit
    result=fixture.verify()
    assert result.returncode!=0 and 'changed during verification' in result.stderr
with PublicFixture() as fixture:
    def add(name):
        fixture.callback=None
        (fixture.expected/'extra.txt').write_text('new')
    fixture.callback=add
    assert fixture.verify().returncode!=0
with PublicFixture() as fixture:
    assert fixture.verify().returncode==0
