/* Benchmark-only Linux wait4 wrapper. Keep Python's pre-exec RSS out of the
 * measured child's peak; this helper itself has only a small C runtime. */
#define _GNU_SOURCE
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>
int main(int argc, char **argv) {
  if (argc < 3) return 2;
  pid_t child = fork();
  if (child < 0) return 1;
  if (child == 0) { execvp(argv[2], argv + 2); perror("execvp"); _exit(127); }
  int status; struct rusage usage; pid_t result;
  do { result = wait4(child, &status, 0, &usage); } while (result < 0 && errno == EINTR);
  if (result < 0) return 1;
  FILE *file = fopen(argv[1], "w");
  if (!file) return 1;
  int failed = fprintf(file, "%ld\n", usage.ru_maxrss) < 0;
  if (fclose(file) != 0 || failed) return 1;
  return WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
}
