#ifndef _LIBPROC_PRIVATE_H_
#define _LIBPROC_PRIVATE_H_
#include "libproc.h"
#if defined(PRIVATE) && \
        defined(_LIBPROC_PRIVATE_H_) 
#include <sys/event.h>
__BEGIN_DECLS
int proc_list_uptrs(pid_t pid, uint64_t *buffer, uint32_t buffersize);
int proc_list_dynkqueueids(int pid, kqueue_id_t *buf, uint32_t bufsz);
int proc_piddynkqueueinfo(int pid, int flavor, kqueue_id_t kq_id, void *buffer,
    int buffersize);
__END_DECLS
#endif 
#endif 