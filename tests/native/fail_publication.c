/* Test-only filesystem fault injection. Never linked into MoonPress. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <signal.h>

static int matches(const char *key, const char *path) {
  const char *wanted = getenv(key);
  return wanted && strcmp(wanted, path) == 0;
}

static void crash_if(const char *key, const char *path) {
  if (matches(key, path)) {
    kill(getpid(), SIGKILL);
    _exit(102);
  }
}

FILE *fopen(const char *path, const char *mode) {
  FILE *(*real_open)(const char *, const char *) = dlsym(RTLD_NEXT, "fopen");
  if (!real_open) _exit(91);
  if (mode[0] == 'w' && matches("MOONPRESS_TEST_FAIL_OPEN", path)) {
    errno = ENOSPC;
    return NULL;
  }
  if (strchr(mode, 'x') && matches("MOONPRESS_TEST_CREATE_BEFORE_OPEN", path)) {
    FILE *other = real_open(path, "wb");
    if (!other) _exit(111);
    fputs("competing writer\n", other);
    fclose(other);
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
  crash_if("MOONPRESS_TEST_KILL_BEFORE_RENAME", target);
  if (matches("MOONPRESS_TEST_FAIL_RENAME", target) ||
      (strstr(source, "/backup/") && matches("MOONPRESS_TEST_FAIL_ROLLBACK", target))) {
    errno = EIO;
    return -1;
  }
  int result = real_rename(source, target);
  if (result == 0) crash_if("MOONPRESS_TEST_KILL_AFTER_RENAME", target);
  return result;
}

int remove(const char *path) {
  int (*real_remove)(const char *) = dlsym(RTLD_NEXT, "remove");
  if (!real_remove) _exit(94);
  if (matches("MOONPRESS_TEST_FAIL_REMOVE", path)) {
    errno = EIO;
    return -1;
  }
  int result = real_remove(path);
  if (result == 0) crash_if("MOONPRESS_TEST_KILL_AFTER_REMOVE", path);
  return result;
}

int rmdir(const char *path) {
  int (*real_rmdir)(const char *) = dlsym(RTLD_NEXT, "rmdir");
  if (!real_rmdir) _exit(103);
  int result = real_rmdir(path);
  if (result == 0) crash_if("MOONPRESS_TEST_KILL_AFTER_RMDIR", path);
  return result;
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

static int stream_matches(const char *key, FILE *stream) {
  char fdpath[64], path[4096];
  snprintf(fdpath, sizeof fdpath, "/proc/self/fd/%d", fileno(stream));
  ssize_t n = readlink(fdpath, path, sizeof path - 1);
  if (n < 0) return 0;
  path[n] = '\0';
  return matches(key, path);
}

int fflush(FILE *stream) {
  int (*real_flush)(FILE *) = dlsym(RTLD_NEXT, "fflush");
  if (!real_flush) _exit(96);
  if (stream && stream_matches("MOONPRESS_TEST_FAIL_FLUSH", stream)) {
    errno = ENOSPC;
    return EOF;
  }
  return real_flush(stream);
}

int fclose(FILE *stream) {
  int (*real_close)(FILE *) = dlsym(RTLD_NEXT, "fclose");
  if (!real_close) _exit(97);
  int fail = stream_matches("MOONPRESS_TEST_FAIL_CLOSE", stream);
  int result = real_close(stream);
  if (fail) { errno = EIO; return EOF; }
  return result;
}

size_t fread(void *data, size_t size, size_t count, FILE *stream) {
  size_t (*real_read)(void *, size_t, size_t, FILE *) = dlsym(RTLD_NEXT, "fread");
  if (!real_read) _exit(98);
  if (count > 1 && stream_matches("MOONPRESS_TEST_FAIL_READ", stream)) {
    size_t result = real_read(data, size, count / 2, stream);
    errno = EIO;
    return result;
  }
  return real_read(data, size, count, stream);
}

int fseek(FILE *stream, long offset, int whence) {
  int (*real_seek)(FILE *, long, int) = dlsym(RTLD_NEXT, "fseek");
  if (!real_seek) _exit(99);
  if (stream_matches("MOONPRESS_TEST_FAIL_SEEK", stream)) {
    errno = EIO;
    return -1;
  }
  return real_seek(stream, offset, whence);
}

long ftell(FILE *stream) {
  long (*real_tell)(FILE *) = dlsym(RTLD_NEXT, "ftell");
  if (!real_tell) _exit(100);
  if (stream_matches("MOONPRESS_TEST_SIZE_LIMIT", stream)) return 2147483648L;
  if (stream_matches("MOONPRESS_TEST_FAIL_SIZE", stream)) {
    errno = EIO;
    return -1;
  }
  return real_tell(stream);
}

int link(const char *source, const char *target) {
  int (*real_link)(const char *, const char *) = dlsym(RTLD_NEXT, "link");
  if (!real_link) _exit(101);
  if (matches("MOONPRESS_TEST_FAIL_LINK", target)) {
    errno = EIO;
    return -1;
  }
  return real_link(source, target);
}
