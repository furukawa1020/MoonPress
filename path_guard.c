/* Native POSIX filesystem boundary only; compiler/build logic lives in MoonBit. */
#define _GNU_SOURCE
#include <sys/stat.h>
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include "moonbit.h"
MOONBIT_FFI_EXPORT int moonpress_path_kind(moonbit_bytes_t path) {
  struct stat st;
  if (lstat((const char *)path, &st) != 0) return errno == ENOENT ? 0 : -1;
  if (S_ISREG(st.st_mode)) return 1;
  if (S_ISDIR(st.st_mode)) return 2;
  return 3; /* symlink, socket, device, etc. */
}

/* Lock the canonical output's parent, including before the output exists.
 * No lock file is created/unlinked: directory inode identity handles aliases
 * and the kernel releases the lock on close/process exit. Siblings deliberately
 * share a lock. Supported boundary: cooperative processes on local Linux FS. */
MOONBIT_FFI_EXPORT int moonpress_lock_output(moonbit_bytes_t path, int shared) {
  char *resolved = realpath((const char *)path, NULL);
  char *parent;
  if (resolved) {
    /* A canonical root has no lockable parent/output boundary. */
    if (strcmp(resolved, "/") == 0) { free(resolved); return -1; }
    char *slash = strrchr(resolved, '/');
    if (slash == resolved) slash[1] = '\0';
    else *slash = '\0';
    parent = resolved;
  } else {
    if (errno != ENOENT) return -1;
    char *copy = strdup((const char *)path);
    if (!copy) return -1;
    char *slash = strrchr(copy, '/');
    if (!slash) parent = realpath(".", NULL);
    else {
      if (slash == copy) slash[1] = '\0';
      else *slash = '\0';
      parent = realpath(copy, NULL);
    }
    free(copy);
    if (!parent) return -1;
  }
  int fd = open(parent, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
  free(parent);
  if (fd < 0) return -1;
  if (flock(fd, (shared ? LOCK_SH : LOCK_EX) | LOCK_NB) != 0) {
    int busy = errno == EWOULDBLOCK || errno == EAGAIN;
    close(fd);
    return busy ? -2 : -1;
  }
  return fd;
}

MOONBIT_FFI_EXPORT void moonpress_unlock_output(int fd) {
  close(fd);
}

/* Same-filesystem per-file publication; transaction decisions stay in MoonBit. */
MOONBIT_FFI_EXPORT int moonpress_replace_file(moonbit_bytes_t source, moonbit_bytes_t target) {
  return rename((const char *)source, (const char *)target) == 0 ? 0 : errno;
}

/* Preserve an existing regular-file inode without copying or changing contents. */
MOONBIT_FFI_EXPORT int moonpress_link_file(moonbit_bytes_t source, moonbit_bytes_t target) {
  return link((const char *)source, (const char *)target) == 0 ? 0 : errno;
}
