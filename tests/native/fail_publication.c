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
#include <fcntl.h>
#include <stdarg.h>

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

/* Associate anonymous staging streams with their intended target for fault tests.
 * Production checks target absence with lstat immediately before O_TMPFILE open. */
static char candidate[4096];
static char anonymous_paths[256][4096];
static int anonymous_synced[256];
static int sync_interrupted;
static int directory_sync_interrupted;
static int selected_sync_calls;
static int selected_kill_sync_calls;
int lstat(const char *path, struct stat *st) {
  int (*real_lstat)(const char *, struct stat *) = dlsym(RTLD_NEXT, "lstat");
  if (!real_lstat) _exit(120);
  snprintf(candidate, sizeof candidate, "%s", path);
  return real_lstat(path, st);
}
int open(const char *path, int flags, ...) {
  int (*real_open)(const char *, int, ...) = dlsym(RTLD_NEXT, "open");
  if (!real_open) _exit(121);
  mode_t mode = 0;
  if ((flags & O_CREAT) || (flags & O_TMPFILE) == O_TMPFILE) {
    va_list args; va_start(args, flags); mode = va_arg(args, int); va_end(args);
  }
  int anonymous = (flags & O_TMPFILE) == O_TMPFILE;
  if (!anonymous && (flags & O_DIRECTORY) && matches("MOONPRESS_TEST_FAIL_DIR_OPEN", path)) { errno=EACCES; return -1; }
  if (anonymous && getenv("MOONPRESS_TEST_UNSUPPORTED_ANONYMOUS")) { errno = EOPNOTSUPP; return -1; }
  if (anonymous && matches("MOONPRESS_TEST_FAIL_OPEN", candidate)) { errno = ENOSPC; return -1; }
  int fd = real_open(path, flags, mode);
  if (anonymous && fd >= 0 && fd < 256) {
    snprintf(anonymous_paths[fd], 4096, "%s", candidate);
    anonymous_synced[fd] = 0;
  }
  return fd;
}
static int directory_matches(const char *key, int fd) {
  struct stat st;
  if (fstat(fd,&st)!=0 || !S_ISDIR(st.st_mode)) return 0;
  char fdpath[64], path[4096];
  snprintf(fdpath,sizeof fdpath,"/proc/self/fd/%d",fd);
  ssize_t n=readlink(fdpath,path,sizeof path-1);
  if(n<0) return 0;
  path[n]=0;
  return matches(key,path);
}
int close(int fd) {
  int (*real_close)(int)=dlsym(RTLD_NEXT,"close");
  if(!real_close) _exit(125);
  int fail=directory_matches("MOONPRESS_TEST_FAIL_DIR_CLOSE",fd);
  int result=real_close(fd);
  if(fail) { errno=EIO; return -1; }
  return result;
}
int fsync(int fd) {
  int (*real_sync)(int) = dlsym(RTLD_NEXT, "fsync");
  if (!real_sync) _exit(124);
  if(directory_matches("MOONPRESS_TEST_FAIL_DIR_SYNC",fd)) { errno=EIO; return -1; }
  if(!directory_sync_interrupted && directory_matches("MOONPRESS_TEST_INTERRUPT_DIR_SYNC",fd)) {
    directory_sync_interrupted=1; errno=EINTR; return -1;
  }
  const char *required=getenv("MOONPRESS_TEST_REQUIRE_LINK_BEFORE_DIR_SYNC");
  struct stat st;
  if(required && fstat(fd,&st)==0 && S_ISDIR(st.st_mode) && lstat(required,&st)!=0) {
    errno=EIO; return -1;
  }
  if (fd >= 0 && fd < 256 && anonymous_paths[fd][0]) {
    if (matches("MOONPRESS_TEST_FAIL_SYNC", anonymous_paths[fd])) { errno=EIO; return -1; }
    if (!sync_interrupted && matches("MOONPRESS_TEST_INTERRUPT_SYNC", anonymous_paths[fd])) {
      sync_interrupted=1; errno=EINTR; return -1;
    }
  }
  char fdname[64], synced_path[4096];
  snprintf(fdname,sizeof fdname,"/proc/self/fd/%d",fd);
  ssize_t length=readlink(fdname,synced_path,sizeof synced_path-1);
  if(length>=0) {
    synced_path[length]=0;
    if(matches("MOONPRESS_TEST_FAIL_EXISTING_SYNC",synced_path)) {
      const char *nth=getenv("MOONPRESS_TEST_FAIL_SYNC_ON_CALL");
      selected_sync_calls++;
      if(!nth || selected_sync_calls==atoi(nth) ||
         (getenv("MOONPRESS_TEST_FAIL_SYNC_FROM_CALL") && selected_sync_calls>=atoi(nth))) { errno=EIO; return -1; }
    }
  }
  int result=real_sync(fd);
  if(result==0 && length>=0) {
    const char *trace=getenv("MOONPRESS_TEST_SYNC_TRACE");
    if(trace) {
      FILE *log=fopen(trace,"a");
      if(!log) _exit(126);
      fprintf(log,"sync %s\n",synced_path); fclose(log);
    }
    if(matches("MOONPRESS_TEST_KILL_AFTER_SYNC",synced_path)) {
      const char *nth=getenv("MOONPRESS_TEST_KILL_SYNC_ON_CALL");
      selected_kill_sync_calls++;
      if(!nth || selected_kill_sync_calls==atoi(nth)) {
        kill(getpid(),SIGKILL); _exit(102);
      }
    }
  }
  if (result==0 && fd>=0 && fd<256) anonymous_synced[fd]=1;
  return result;
}
static int stream_matches(const char *key, FILE *stream);

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
  if (count > 1 && stream_matches("MOONPRESS_TEST_FAIL_WRITE", stream)) {
    size_t written = real_write(data, size, count / 2, stream);
    fflush(stream);
    errno = ENOSPC;
    return written;
  }
  if (stream_matches("MOONPRESS_TEST_KILL_DURING_WRITE", stream)) {
    real_write(data, size, count / 2, stream);
    fflush(stream);
    kill(getpid(), SIGKILL);
    _exit(122);
  }
  return real_write(data, size, count, stream);
}

int rename(const char *source, const char *target) {
  int (*real_rename)(const char *, const char *) = dlsym(RTLD_NEXT, "rename");
  if (!real_rename) _exit(93);
  const char *trace=getenv("MOONPRESS_TEST_SYNC_TRACE");
  if(trace) {
    FILE *log=fopen(trace,"a");
    if(!log) _exit(127);
    fprintf(log,"rename %s\n",target); fclose(log);
  }
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
  if (matches("MOONPRESS_TEST_FAIL_RMDIR", path)) { errno = EACCES; return -1; }
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
  int result = real_mkdir(path, mode);
  if (result == 0) crash_if("MOONPRESS_TEST_KILL_AFTER_MKDIR", path);
  return result;
}

static int stream_matches(const char *key, FILE *stream) {
  int fd = fileno(stream);
  if (fd >= 0 && fd < 256 && anonymous_paths[fd][0]) return matches(key, anonymous_paths[fd]);
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
  int edit = stream_matches("MOONPRESS_TEST_EDIT_ON_CLOSE", stream);
  int fd = fileno(stream);
  int result = real_close(stream);
  if (fd >= 0 && fd < 256) anonymous_paths[fd][0] = 0;
  if (edit) {
    const char *target = getenv("MOONPRESS_TEST_EDIT_TARGET");
    if (!target) _exit(112);
    FILE *other = fopen(target, "wb");
    if (!other) _exit(113);
    fputs("# External edit\n", other);
    fclose(other);
  }
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

/* Fortified glibc builds call this entry point instead of fread. Keep the
 * real bounds check and inject the same short-read fault as the plain symbol. */
size_t __fread_chk(void *data, size_t capacity, size_t size, size_t count, FILE *stream) {
  size_t (*real_read)(void *, size_t, size_t, size_t, FILE *) = dlsym(RTLD_NEXT, "__fread_chk");
  if (!real_read) _exit(128);
  if (count > 1 && stream_matches("MOONPRESS_TEST_FAIL_READ", stream)) {
    size_t result = real_read(data, capacity, size, count / 2, stream);
    errno = EIO;
    return result;
  }
  return real_read(data, capacity, size, count, stream);
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
  if (matches("MOONPRESS_TEST_CREATE_BEFORE_LINK", target)) {
    FILE *other = fopen(target, "wbx");
    if (!other) _exit(114);
    fputs("competing writer\n", other);
    fclose(other);
  }
  return real_link(source, target);
}

/* Descriptor-relative authoring uses the same test fault controls. */
#include <fcntl.h>
#include <stdarg.h>
static void at_path(int directory, const char *name, char *path, size_t size) {
  if (name[0]=='/' || directory==AT_FDCWD) { snprintf(path,size,"%s",name); return; }
  char fdpath[64], parent[4096];
  snprintf(fdpath,sizeof fdpath,"/proc/self/fd/%d",directory);
  ssize_t n=readlink(fdpath,parent,sizeof parent-1);
  if(n<0) _exit(115);
  parent[n]=0;
  if (snprintf(path,size,"%s/%s",parent,name)>=(int)size) _exit(116);
}
int fstatat(int directory, const char *name, struct stat *st, int flags) {
  int (*real_stat)(int,const char*,struct stat*,int)=dlsym(RTLD_NEXT,"fstatat");
  if (!real_stat) _exit(129);
  at_path(directory,name,candidate,sizeof candidate);
  return real_stat(directory,name,st,flags);
}
int openat(int directory, const char *name, int flags, ...) {
  int (*real_open)(int,const char*,int,...)=dlsym(RTLD_NEXT,"openat");
  mode_t mode=0;
  int anonymous=(flags&O_TMPFILE)==O_TMPFILE;
  if((flags&O_CREAT) || anonymous) { va_list ap; va_start(ap,flags); mode=va_arg(ap,int); va_end(ap); }
  char path[8192]; at_path(directory,name,path,sizeof path);
  if(anonymous) {
    if(getenv("MOONPRESS_TEST_UNSUPPORTED_ANONYMOUS")) { errno=EOPNOTSUPP; return -1; }
    if(matches("MOONPRESS_TEST_FAIL_OPEN",candidate)) { errno=ENOSPC; return -1; }
    int fd=real_open(directory,name,flags,mode);
    if(fd>=0 && fd<256) {
      snprintf(anonymous_paths[fd],4096,"%s",candidate);
      anonymous_synced[fd]=0;
    }
    return fd;
  }
  if((flags&O_CREAT) && matches("MOONPRESS_TEST_FAIL_OPEN",path)) { errno=ENOSPC; return -1; }
  if((flags&O_EXCL) && matches("MOONPRESS_TEST_CREATE_BEFORE_OPEN",path)) {
    int other=real_open(directory,name,O_WRONLY|O_CREAT|O_EXCL,0600);
    if(other<0) _exit(117);
    if(write(other,"competing writer\n",17)!=17) _exit(118);
    close(other);
  }
  return real_open(directory,name,flags,mode);
}
int renameat(int source_dir,const char *source,int target_dir,const char *target) {
  int (*real_rename)(int,const char*,int,const char*)=dlsym(RTLD_NEXT,"renameat");
  char path[8192]; at_path(target_dir,target,path,sizeof path);
  crash_if("MOONPRESS_TEST_KILL_BEFORE_RENAME",path);
  if(matches("MOONPRESS_TEST_FAIL_RENAME",path)) { errno=EIO; return -1; }
  int result=real_rename(source_dir,source,target_dir,target);
  if(result==0) crash_if("MOONPRESS_TEST_KILL_AFTER_RENAME",path);
  return result;
}
int unlinkat(int directory,const char *name,int flags) {
  int (*real_remove)(int,const char*,int)=dlsym(RTLD_NEXT,"unlinkat");
  char path[8192]; at_path(directory,name,path,sizeof path);
  if(matches("MOONPRESS_TEST_FAIL_REMOVE",path)) { errno=EIO; return -1; }
  return real_remove(directory,name,flags);
}
int linkat(int source_dir,const char *source,int target_dir,const char *target,int flags) {
  int (*real_link)(int,const char*,int,const char*,int)=dlsym(RTLD_NEXT,"linkat");
  char path[8192]; at_path(target_dir,target,path,sizeof path);
  if(matches("MOONPRESS_TEST_REQUIRE_SYNC",path)) {
    int fd=-1;
    if(sscanf(source,"/proc/self/fd/%d",&fd)!=1 || fd<0 || fd>=256 || !anonymous_synced[fd]) {
      errno=EIO; return -1;
    }
  }
  if(matches("MOONPRESS_TEST_FAIL_INSTALL",path)) { errno=EACCES; return -1; }
  if(matches("MOONPRESS_TEST_FAIL_LINK",path)) { errno=EIO; return -1; }
  if(matches("MOONPRESS_TEST_CREATE_BEFORE_LINK",path)) {
    FILE *other=fopen(path,"wbx");
    if(!other) _exit(119);
    fputs("competing writer\n",other); fclose(other);
  }
  return real_link(source_dir,source,target_dir,target,flags);
}
