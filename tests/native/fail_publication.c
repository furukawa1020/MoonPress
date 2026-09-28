/* Test-only filesystem fault injection. Never linked into MoonPress. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

static int matches(const char *key, const char *path) {
  const char *wanted = getenv(key);
  return wanted && strcmp(wanted, path) == 0;
}

FILE *fopen(const char *path, const char *mode) {
  FILE *(*real_open)(const char *, const char *) = dlsym(RTLD_NEXT, "fopen");
  if (!real_open) _exit(91);
  if (mode[0] == 'w' && matches("MOONPRESS_TEST_FAIL_OPEN", path)) {
    errno = ENOSPC;
    return NULL;
  }
  return real_open(path, mode);
}

size_t fwrite(const void *data, size_t size, size_t count, FILE *stream) {
  size_t (*real_write)(const void *, size_t, size_t, FILE *) = dlsym(RTLD_NEXT, "fwrite");
  if (!real_write) _exit(92);
  char fdpath[64], path[4096];
  snprintf(fdpath, sizeof fdpath, "/proc/self/fd/%d", fileno(stream));
  ssize_t n = readlink(fdpath, path, sizeof path - 1);
  if (n >= 0) {
    path[n] = '\0';
    if (count > 1 && matches("MOONPRESS_TEST_FAIL_WRITE", path)) {
      size_t written = real_write(data, size, count / 2, stream);
      fflush(stream);
      errno = ENOSPC;
      return written;
    }
  }
  return real_write(data, size, count, stream);
}

int rename(const char *source, const char *target) {
  int (*real_rename)(const char *, const char *) = dlsym(RTLD_NEXT, "rename");
  if (!real_rename) _exit(93);
  if (matches("MOONPRESS_TEST_FAIL_RENAME", target)) {
    errno = EIO;
    return -1;
  }
  return real_rename(source, target);
}

int remove(const char *path) {
  int (*real_remove)(const char *) = dlsym(RTLD_NEXT, "remove");
  if (!real_remove) _exit(94);
  if (matches("MOONPRESS_TEST_FAIL_REMOVE", path)) {
    errno = EIO;
    return -1;
  }
  return real_remove(path);
}

int mkdir(const char *path, mode_t mode) {
  int (*real_mkdir)(const char *, mode_t) = dlsym(RTLD_NEXT, "mkdir");
  if (!real_mkdir) _exit(95);
  if (matches("MOONPRESS_TEST_FAIL_MKDIR", path)) {
    errno = ENOSPC;
    return -1;
  }
  return real_mkdir(path, mode);
}
