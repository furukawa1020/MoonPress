/* Thin stdio operations only; ownership/error policy lives in MoonBit. */
#define _GNU_SOURCE
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <stdint.h>
#include "moonbit.h"

MOONBIT_FFI_EXPORT FILE *moonpress_io_open(moonbit_bytes_t path, int write_mode) {
  return fopen((const char *)path, write_mode == 2 ? "wbx" : (write_mode ? "wb" : "rb"));
}
MOONBIT_FFI_EXPORT int moonpress_io_is_null(FILE *file) { return file == NULL; }
MOONBIT_FFI_EXPORT int moonpress_io_write(FILE *file, moonbit_bytes_t data, int length) {
  errno = 0;
  return (int)fwrite(data, 1, (size_t)length, file);
}
MOONBIT_FFI_EXPORT int moonpress_io_flush(FILE *file) { return fflush(file); }
MOONBIT_FFI_EXPORT int moonpress_io_close(FILE *file) { return fclose(file); }
MOONBIT_FFI_EXPORT int moonpress_io_errno(void) { return errno; }

MOONBIT_FFI_EXPORT int moonpress_io_seek(FILE *file, int whence) {
  return fseek(file, 0, whence);
}
MOONBIT_FFI_EXPORT int64_t moonpress_io_size(FILE *file) { return (int64_t)ftell(file); }
MOONBIT_FFI_EXPORT int moonpress_io_read(FILE *file, moonbit_bytes_t data, int length) {
  errno = 0;
  return (int)fread(data, 1, (size_t)length, file);
}

MOONBIT_FFI_EXPORT int moonpress_io_copy_mode(FILE *file, moonbit_bytes_t path) {
  struct stat st;
  if (lstat((const char *)path, &st) != 0) return -1;
  if (!S_ISREG(st.st_mode)) { errno = EINVAL; return -1; }
  return fchmod(fileno(file), st.st_mode & 0777);
}

/* Read-only directory walking. Never follow a symlink in the supplied path. */
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>

static int moonpress_open_real_directory(const char *path) {
  if (!path[0]) { errno = ENOENT; return -1; }
  char *copy = strdup(path);
  if (!copy) return -1;
  int fd = open(path[0] == '/' ? "/" : ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
  if (fd < 0) { int saved = errno; free(copy); errno = saved; return -1; }
  char *save = NULL;
  for (char *part = strtok_r(copy, "/", &save); part; part = strtok_r(NULL, "/", &save)) {
    int next = openat(fd, part, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    int saved = errno;
    close(fd);
    if (next < 0) { free(copy); errno = saved; return -1; }
    fd = next;
  }
  free(copy);
  return fd;
}

/* Consumes the directory descriptor on all paths. */
static FILE *moonpress_open_regular_at(int directory, const char *name) {
  int fd = openat(directory, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
  int saved = errno;
  close(directory);
  if (fd < 0) { errno = saved; return NULL; }
  struct stat st;
  if (fstat(fd, &st) != 0) {
    saved = errno; close(fd); errno = saved; return NULL;
  }
  if (!S_ISREG(st.st_mode)) { close(fd); errno = EINVAL; return NULL; }
  FILE *file = fdopen(fd, "rb");
  if (!file) { saved = errno; close(fd); errno = saved; }
  return file;
}

/* Anchor public/ and its flat child before reading. */
MOONBIT_FFI_EXPORT FILE *moonpress_io_open_public(moonbit_bytes_t input, moonbit_bytes_t name) {
  int root = moonpress_open_real_directory((const char *)input);
  if (root < 0) return NULL;
  int directory = openat(root, "public", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
  int saved = errno;
  close(root);
  if (directory < 0) { errno = saved; return NULL; }
  return moonpress_open_regular_at(directory, (const char *)name);
}

/* Retained directory operations: callers own and close the descriptor. */
MOONBIT_FFI_EXPORT int moonpress_dir_open(moonbit_bytes_t path) {
  return moonpress_open_real_directory((const char *)path);
}
MOONBIT_FFI_EXPORT void moonpress_dir_close(int directory) { close(directory); }
MOONBIT_FFI_EXPORT int moonpress_dir_kind(int directory, moonbit_bytes_t name) {
  struct stat st;
  if (fstatat(directory, (const char *)name, &st, AT_SYMLINK_NOFOLLOW) != 0)
    return errno == ENOENT ? 0 : -1;
  return S_ISREG(st.st_mode) ? 1 : (S_ISDIR(st.st_mode) ? 2 : 3);
}
MOONBIT_FFI_EXPORT FILE *moonpress_dir_read(int directory, moonbit_bytes_t name) {
  int copy = dup(directory);
  if (copy < 0) return NULL;
  return moonpress_open_regular_at(copy, (const char *)name);
}

#include <sys/file.h>
MOONBIT_FFI_EXPORT int moonpress_dir_lock(int directory) {
  if (flock(directory, LOCK_EX | LOCK_NB) == 0) return 0;
  return errno == EAGAIN || errno == EWOULDBLOCK ? -2 : -1;
}
MOONBIT_FFI_EXPORT FILE *moonpress_dir_create(int directory, moonbit_bytes_t name) {
  int fd = openat(directory, (const char *)name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0666);
  if (fd < 0) return NULL;
  FILE *file = fdopen(fd, "wb");
  if (!file) {
    int saved = errno;
    close(fd);
    /* Creation succeeded: leave the file for explicit inspection on stream failure. */
    errno = saved;
  }
  return file;
}
MOONBIT_FFI_EXPORT int moonpress_dir_copy_mode(int directory, FILE *file, moonbit_bytes_t name) {
  struct stat st;
  if (fstatat(directory, (const char *)name, &st, AT_SYMLINK_NOFOLLOW) != 0) return -1;
  if (!S_ISREG(st.st_mode)) { errno = EINVAL; return -1; }
  return fchmod(fileno(file), st.st_mode & 0777);
}
MOONBIT_FFI_EXPORT int moonpress_dir_publish(int directory, moonbit_bytes_t stage, moonbit_bytes_t target, int exclusive) {
  return exclusive ? linkat(directory, (const char *)stage, directory, (const char *)target, 0)
                   : renameat(directory, (const char *)stage, directory, (const char *)target);
}
MOONBIT_FFI_EXPORT int moonpress_dir_remove(int directory, moonbit_bytes_t name) {
  return unlinkat(directory, (const char *)name, 0);
}

MOONBIT_FFI_EXPORT int moonpress_dir_same(int a, int b) {
  struct stat left, right;
  if (fstat(a, &left) != 0 || fstat(b, &right) != 0) return -1;
  return left.st_dev == right.st_dev && left.st_ino == right.st_ino;
}

/* Compare retained directory identities while walking ancestors. */
MOONBIT_FFI_EXPORT int moonpress_dir_within(int directory, int root) {
  struct stat target;
  if (fstat(root, &target) != 0) return -1;
  int current = dup(directory);
  if (current < 0) return -1;
  for (int depth = 0; depth < 1024; depth++) {
    struct stat here, above;
    if (fstat(current, &here) != 0) { close(current); return -1; }
    if (here.st_dev == target.st_dev && here.st_ino == target.st_ino) {
      close(current); return 1;
    }
    int parent = openat(current, "..", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (parent < 0) { close(current); return -1; }
    if (fstat(parent, &above) != 0) { close(parent); close(current); return -1; }
    close(current);
    if (here.st_dev == above.st_dev && here.st_ino == above.st_ino) {
      close(parent); return 0;
    }
    current = parent;
  }
  close(current);
  return -1;
}

/* Read-only compiler input identity: ancestors may be aliases, final root may not. */
MOONBIT_FFI_EXPORT int moonpress_input_directory_open(moonbit_bytes_t path) {
  return open((const char *)path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
}

/* Anonymous complete-or-absent publication, Linux local filesystems only. */
MOONBIT_FFI_EXPORT FILE *moonpress_atomic_open(moonbit_bytes_t target) {
  struct stat st;
  if (lstat((const char *)target, &st) == 0) { errno = EEXIST; return NULL; }
  if (errno != ENOENT) return NULL;
  char *copy = strdup((const char *)target);
  if (!copy) return NULL;
  char *slash = strrchr(copy, '/');
  if (slash) { if (slash == copy) slash[1] = 0; else *slash = 0; }
  int fd = open(slash ? copy : ".", O_TMPFILE | O_RDWR | O_CLOEXEC, 0666);
  int saved = errno;
  free(copy);
  if (fd < 0) { errno = saved; return NULL; }
  FILE *file = fdopen(fd, "wb");
  if (!file) { saved = errno; close(fd); errno = saved; }
  return file;
}
MOONBIT_FFI_EXPORT int moonpress_atomic_install(FILE *file, moonbit_bytes_t target) {
  char source[64];
  snprintf(source, sizeof source, "/proc/self/fd/%d", fileno(file));
  return linkat(AT_FDCWD, source, AT_FDCWD, (const char *)target, AT_SYMLINK_FOLLOW);
}
