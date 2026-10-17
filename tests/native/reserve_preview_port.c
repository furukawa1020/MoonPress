/* Test only: reserve an available adjacent pair, then hold its preview port. */
#define _POSIX_C_SOURCE 200809L
#include <arpa/inet.h>
#include <sys/socket.h>
#include <stdio.h>
#include <unistd.h>
int main(void) {
  for (int attempt=0; attempt<100; attempt++) {
    int first=socket(AF_INET,SOCK_STREAM,0), second=socket(AF_INET,SOCK_STREAM,0);
    if(first<0 || second<0) return 1;
    struct sockaddr_in address={0};
    address.sin_family=AF_INET;
    address.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
    socklen_t length=sizeof address;
    if(bind(first,(struct sockaddr*)&address,sizeof address)!=0 || getsockname(first,(struct sockaddr*)&address,&length)!=0) return 2;
    unsigned port=ntohs(address.sin_port);
    if(port<1024 || port>=65535) { close(first); close(second); continue; }
    address.sin_port=htons((unsigned short)(port+1));
    if(bind(second,(struct sockaddr*)&address,sizeof address)!=0 || listen(second,1)!=0) { close(first); close(second); continue; }
    close(first);
    printf("%u\n",port);
    fflush(stdout);
    for(;;) pause();
  }
  return 3;
}
