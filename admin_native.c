/* Loopback socket/random-byte boundary. HTTP, forms and authoring live in MoonBit. */
#define _GNU_SOURCE
#include <arpa/inet.h>
#include <errno.h>
#include <poll.h>
#include <stdint.h>
#include <sys/random.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>
#include "moonbit.h"
static int64_t deadline;
static int64_t now_ms(void) {
  struct timespec t;
  if (clock_gettime(CLOCK_MONOTONIC, &t)) return 0;
  return (int64_t)t.tv_sec * 1000 + t.tv_nsec / 1000000;
}
static int wait_fd(int fd, short events, int64_t until) {
  for (;;) {
    int64_t remaining = until - now_ms();
    if (remaining <= 0) return -1;
    struct pollfd p = {fd, events, 0};
    int r = poll(&p, 1, (int)remaining);
    if (r < 0 && errno == EINTR) continue;
    return r > 0 && (p.revents & events) ? 0 : -1;
  }
}
MOONBIT_FFI_EXPORT int moonpress_admin_listen(int port) {
  int fd = socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC, 0);
  if (fd < 0) return -1;
  struct sockaddr_in addr = {0};
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  addr.sin_port = htons((uint16_t)port);
  if (bind(fd, (struct sockaddr *)&addr, sizeof addr) || listen(fd, 8)) {
    close(fd); return -1;
  }
  return fd;
}
MOONBIT_FFI_EXPORT int moonpress_admin_accept(int server) {
  int fd;
  do { fd = accept4(server, NULL, NULL, SOCK_CLOEXEC | SOCK_NONBLOCK); }
  while (fd < 0 && errno == EINTR);
  deadline = now_ms() + 5000;
  return fd;
}
MOONBIT_FFI_EXPORT int moonpress_admin_recv(int fd, moonbit_bytes_t bytes, int length) {
  for (;;) {
    if (wait_fd(fd, POLLIN, deadline)) return -1;
    int n = (int)recv(fd, bytes, (size_t)length, 0);
    if (n < 0 && (errno == EINTR || errno == EAGAIN)) continue;
    return n;
  }
}
MOONBIT_FFI_EXPORT int moonpress_admin_send(int fd, moonbit_bytes_t bytes, int length) {
  int offset = 0;
  int64_t until = now_ms() + 5000;
  while (offset < length) {
    if (wait_fd(fd, POLLOUT, until)) return -1;
    int n = (int)send(fd, bytes + offset, (size_t)(length - offset), MSG_NOSIGNAL);
    if (n < 0 && (errno == EINTR || errno == EAGAIN)) continue;
    if (n <= 0) return -1;
    offset += n;
  }
  return 0;
}
MOONBIT_FFI_EXPORT void moonpress_admin_close(int fd) { close(fd); }
MOONBIT_FFI_EXPORT int moonpress_admin_random(moonbit_bytes_t bytes) {
  int offset = 0;
  while (offset < 32) {
    int n = (int)getrandom(bytes + offset, (size_t)(32 - offset), 0);
    if (n < 0 && errno == EINTR) continue;
    if (n <= 0) return -1;
    offset += n;
  }
  return 0;
}
#include <stdio.h>
MOONBIT_FFI_EXPORT void moonpress_admin_flush(void) { fflush(stdout); }
