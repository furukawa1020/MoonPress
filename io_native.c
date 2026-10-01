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
