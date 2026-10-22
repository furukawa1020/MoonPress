#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

int renameat(int olddir, const char *oldname, int newdir, const char *newname) {
  static int (*next)(int, const char *, int, const char *);
  if (!next) *(void **)(&next) = dlsym(RTLD_NEXT, "renameat");
  const char *ready = getenv("MOONPRESS_REST_READY");
  const char *release = getenv("MOONPRESS_REST_RELEASE");
  if (ready && release && strcmp(oldname, ".moonpress-edit") == 0) {
    char arm[4096];
    if (snprintf(arm, sizeof arm, "%s", ready) >= (int)sizeof arm) { errno = EINVAL; return -1; }
    char *slash = strrchr(arm, '/');
    if (!slash || (size_t)(slash - arm) + 1 + sizeof "arm" > sizeof arm) { errno = EINVAL; return -1; }
    strcpy(slash + 1, "arm");
    if (access(arm, F_OK) == 0) {
      unlink(arm);
      int marker = open(ready, O_WRONLY | O_CREAT | O_EXCL, 0600);
      if (marker < 0) return -1;
      close(marker);
      struct timespec delay = {0, 10000000};
      for (int i = 0; i < 600 && access(release, F_OK) != 0; i++) nanosleep(&delay, NULL);
      if (access(release, F_OK) != 0) { errno = ETIMEDOUT; return -1; }
    }
  }
  return next(olddir, oldname, newdir, newname);
}
