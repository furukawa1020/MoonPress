/* Test only: replace a directory after its real no-follow open succeeds. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
int openat(int parent, const char *name, int flags, ...) {
  int (*real_open)(int,const char*,int,...) = dlsym(RTLD_NEXT,"openat");
  mode_t mode = 0;
  if (flags & O_CREAT) { va_list ap; va_start(ap,flags); mode=va_arg(ap,int); va_end(ap); }
  int fd=real_open(parent,name,flags,mode);
  static int changed=0;
  const char *wanted=getenv("MOONPRESS_SWAP_DIRECTORY");
  if (fd>=0 && !changed && wanted && (flags & O_DIRECTORY)) {
    char link[64], path[4096];
    snprintf(link,sizeof link,"/proc/self/fd/%d",fd);
    ssize_t n=readlink(link,path,sizeof path-1);
    if(n>=0) {
      path[n]=0;
      if(strcmp(path,wanted)==0) {
        const char *moved=getenv("MOONPRESS_SWAP_MOVED");
        const char *foreign=getenv("MOONPRESS_SWAP_FOREIGN");
        changed=1;
        if(!moved || !foreign || rename(wanted,moved)!=0 || symlink(foreign,wanted)!=0) _exit(91);
      }
    }
  }
  return fd;
}
