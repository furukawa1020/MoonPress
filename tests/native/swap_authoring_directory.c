/* Test only: deterministic directory replacement at operation boundaries. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/file.h>
static void swap_at(int fd, const char *event) {
  static int changed=0;
  const char *wanted=getenv("MOONPRESS_SWAP_DIRECTORY");
  const char *phase=getenv("MOONPRESS_SWAP_PHASE");
  if(!phase) phase="open";
  if(fd<0 || changed || !wanted || strcmp(phase,event)!=0) return;
  char link[64],path[4096];
  snprintf(link,sizeof link,"/proc/self/fd/%d",fd);
  ssize_t n=readlink(link,path,sizeof path-1);
  if(n<0) _exit(90);
  path[n]=0;
  size_t length=strlen(wanted);
  if(strncmp(path,wanted,length)!=0 || (path[length] && path[length]!='/')) return;
  const char *moved=getenv("MOONPRESS_SWAP_MOVED");
  const char *foreign=getenv("MOONPRESS_SWAP_FOREIGN");
  changed=1;
  if(!moved || !foreign || rename(wanted,moved)!=0 || symlink(foreign,wanted)!=0) _exit(91);
}
int openat(int parent,const char *name,int flags,...) {
  int (*real_open)(int,const char*,int,...)=dlsym(RTLD_NEXT,"openat");
  mode_t mode=0;
  if(flags&O_CREAT) { va_list ap; va_start(ap,flags); mode=va_arg(ap,int); va_end(ap); swap_at(parent,"create"); }
  int fd=real_open(parent,name,flags,mode);
  if(flags&O_DIRECTORY) swap_at(fd,"open");
  return fd;
}
int flock(int fd,int operation) {
  int (*real_lock)(int,int)=dlsym(RTLD_NEXT,"flock");
  int result=real_lock(fd,operation);
  if(result==0 && (operation&LOCK_EX)) swap_at(fd,"lock");
  return result;
}
int renameat(int source_dir,const char *source,int target_dir,const char *target) {
  int (*real_rename)(int,const char*,int,const char*)=dlsym(RTLD_NEXT,"renameat");
  swap_at(source_dir,"publish");
  return real_rename(source_dir,source,target_dir,target);
}
int linkat(int source_dir,const char *source,int target_dir,const char *target,int flags) {
  int (*real_link)(int,const char*,int,const char*,int)=dlsym(RTLD_NEXT,"linkat");
  swap_at(source_dir,"publish");
  return real_link(source_dir,source,target_dir,target,flags);
}
int unlinkat(int directory,const char *name,int flags) {
  int (*real_remove)(int,const char*,int)=dlsym(RTLD_NEXT,"unlinkat");
  swap_at(directory,"cleanup");
  return real_remove(directory,name,flags);
}
