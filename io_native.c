/* Thin stdio operations only; ownership/error policy lives in MoonBit. */
#define _POSIX_C_SOURCE 200809L
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

/* Anchor public/ and its flat child to open descriptors, then validate the
 * actual file. O_NONBLOCK prevents a substituted FIFO from blocking open. */
MOONBIT_FFI_EXPORT FILE *moonpress_io_open_public(moonbit_bytes_t input, moonbit_bytes_t name) {
  int root = moonpress_open_real_directory((const char *)input);
  if (root < 0) return NULL;
  int directory = openat(root, "public", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
  int saved = errno;
  close(root);
  if (directory < 0) { errno = saved; return NULL; }
  int fd = openat(directory, (const char *)name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
  saved = errno;
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
