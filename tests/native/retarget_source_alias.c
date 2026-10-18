/* Test only: retarget an input ancestor after the destination lock is acquired. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/file.h>
int flock(int fd, int operation) {
  int (*real_lock)(int,int) = dlsym(RTLD_NEXT, "flock");
  int result = real_lock(fd, operation);
  static int changed = 0;
  const char *alias = getenv("MOONPRESS_RETARGET_ALIAS");
  const char *target = getenv("MOONPRESS_RETARGET_TARGET");
  if (!changed && result == 0 && (operation & LOCK_EX) && alias && target) {
    changed = 1;
    if (unlink(alias) != 0 || symlink(target, alias) != 0) _exit(91);
  }
  return result;
}
