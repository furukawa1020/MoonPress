/* Native POSIX filesystem boundary only; compiler/build logic lives in MoonBit. */
#include <sys/stat.h>
#include <errno.h>
#include "moonbit.h"
MOONBIT_FFI_EXPORT int moonpress_path_kind(moonbit_bytes_t path) {
  struct stat st;
  if (lstat((const char *)path, &st) != 0) return errno == ENOENT ? 0 : -1;
  if (S_ISREG(st.st_mode)) return 1;
  if (S_ISDIR(st.st_mode)) return 2;
  return 3; /* symlink, socket, device, etc. */
}
