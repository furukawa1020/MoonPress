from pages_verification_fixture import *
import os
with PublicFixture() as fixture:
    link=fixture.expected/'linked';link.symlink_to(fixture.expected/'index.html')
    assert fixture.verify().returncode!=0 and fixture.requests==[]
    link.unlink();folder=fixture.expected/'nested';folder.mkdir()
    assert fixture.verify().returncode!=0 and fixture.requests==[]
    folder.rmdir();fifo=fixture.expected/'pipe';os.mkfifo(fifo)
    assert fixture.verify().returncode!=0 and fixture.requests==[]
    fifo.unlink();assert fixture.verify().returncode==0
