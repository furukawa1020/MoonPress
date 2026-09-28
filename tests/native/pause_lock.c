/* Test-only LD_PRELOAD fixture: pause a real CLI after acquiring its lock.
 * This file is never linked into MoonPress. */
#define _GNU_SOURCE
#include <sys/file.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>

int flock(int fd, int operation) {
  int (*real_flock)(int, int) = dlsym(RTLD_NEXT, "flock");
  if (!real_flock) _exit(91);
  int result = real_flock(fd, operation);
  const char *ready = getenv("MOONPRESS_TEST_LOCK_READY");
  const char *release = getenv("MOONPRESS_TEST_LOCK_RELEASE");
  if (result == 0 && (operation & LOCK_EX) && ready && release) {
    int marker = open(ready, O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (marker < 0) _exit(92);
    close(marker);
    for (int i = 0; i < 1000; i++) {
      if (access(release, F_OK) == 0) return result;
      usleep(10000);
    }
    _exit(93);
  }
  return result;
}
