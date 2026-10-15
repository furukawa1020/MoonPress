/* Test-only: mutate replacement staging after its first close. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

int fclose(FILE *stream) {
  int (*real_close)(FILE *) = dlsym(RTLD_NEXT, "fclose");
  if (!real_close) _exit(91);
  static int changed = 0;
  const char *stage = getenv("MOONPRESS_TEST_MEDIA_STAGE");
  const char *action = getenv("MOONPRESS_TEST_STAGE_ACTION");
  char fdpath[64], path[4096];
  snprintf(fdpath, sizeof fdpath, "/proc/self/fd/%d", fileno(stream));
  ssize_t n = readlink(fdpath, path, sizeof path - 1);
  if (n >= 0) path[n] = '\0';
  int mutate = !changed && stage && action && n >= 0 && strcmp(path, stage) == 0;
  int result = real_close(stream);
  if (!mutate) return result;
  changed = 1;
  if (strcmp(action, "edit") == 0) {
    FILE *file = fopen(stage, "wb");
    if (!file) _exit(92);
    fputs("foreign staged bytes", file);
    fclose(file);
  } else {
    if (unlink(stage) != 0) _exit(93);
    if (strcmp(action, "symlink") == 0) {
      const char *target = getenv("MOONPRESS_TEST_STAGE_LINK");
      if (!target || symlink(target, stage) != 0) _exit(94);
    } else if (strcmp(action, "directory") == 0) {
      if (mkdir(stage, 0700) != 0) _exit(95);
    } else if (strcmp(action, "remove") != 0) {
      _exit(96);
    }
  }
  return result;
}
