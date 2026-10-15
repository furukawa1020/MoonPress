/* Test-only: substitute paths precisely between preflight and guarded open. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static void change_path(const char *path) {
  static int changed = 0;
  const char *action = getenv("MOONPRESS_TEST_MEDIA_SWAP");
  const char *target = getenv("MOONPRESS_TEST_MEDIA_TARGET");
  const char *outside = getenv("MOONPRESS_TEST_MEDIA_OUTSIDE");
  if (changed || !action || !target || !outside) return;
  int directory = strcmp(action, "public") == 0;
  if (strcmp(action, "fail-stream") == 0) return;
  if (strcmp(path, directory ? "public" : "a.png") != 0 && strcmp(path, target) != 0) return;
  changed = 1;
  if (directory) {
    char saved[4096];
    if (snprintf(saved, sizeof saved, "%s.saved", target) >= (int)sizeof saved) _exit(91);
    if (rename(target, saved) != 0 || symlink(outside, target) != 0) _exit(92);
  } else {
    if (unlink(target) != 0) _exit(93);
    if (strcmp(action, "fifo") == 0) {
      if (mkfifo(target, 0600) != 0) _exit(94);
    } else if (symlink(outside, target) != 0) _exit(95);
  }
}
int openat(int dirfd, const char *path, int flags, ...) {
  int (*real_openat)(int, const char *, int, ...) = dlsym(RTLD_NEXT, "openat");
  if (!real_openat) _exit(96);
  mode_t mode = 0;
  if (flags & O_CREAT) { va_list args; va_start(args, flags); mode = va_arg(args, int); va_end(args); }
  change_path(path);
  return real_openat(dirfd, path, flags, mode);
}
FILE *fopen(const char *path, const char *mode) {
  FILE *(*real_open)(const char *, const char *) = dlsym(RTLD_NEXT, "fopen");
  if (!real_open) _exit(97);
  if (mode[0] == 'r') change_path(path);
  return real_open(path, mode);
}
FILE *fdopen(int fd, const char *mode) {
  FILE *(*real_fdopen)(int, const char *) = dlsym(RTLD_NEXT, "fdopen");
  if (!real_fdopen) _exit(98);
  const char *action = getenv("MOONPRESS_TEST_MEDIA_SWAP");
  const char *target = getenv("MOONPRESS_TEST_MEDIA_TARGET");
  if (action && target && strcmp(action, "fail-stream") == 0) {
    char fdpath[64], path[4096];
    snprintf(fdpath, sizeof fdpath, "/proc/self/fd/%d", fd);
    ssize_t n = readlink(fdpath, path, sizeof path - 1);
    if (n >= 0) {
      path[n] = '\0';
      if (strcmp(path, target) == 0) { errno = EMFILE; return NULL; }
    }
  }
  return real_fdopen(fd, mode);
}
