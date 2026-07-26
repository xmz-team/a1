#ifndef KPI_KERN_CONTROL_H
#define KPI_KERN_CONTROL_H
#include <sys/appleapiopts.h>
#include <sys/_types/_u_char.h>
#include <sys/_types/_u_int16_t.h>
#include <sys/_types/_u_int32_t.h>
#define KEV_CTL_SUBCLASS        2
#define KEV_CTL_REGISTERED      1       
#define KEV_CTL_DEREGISTERED    2       
struct ctl_event_data {
	u_int32_t   ctl_id;             
	u_int32_t   ctl_unit;
};
#define CTLIOCGCOUNT    _IOR('N', 2, int)               
#define CTLIOCGINFO     _IOWR('N', 3, struct ctl_info)  
#define MAX_KCTL_NAME   96
struct ctl_info {
	u_int32_t   ctl_id;                             
	char        ctl_name[MAX_KCTL_NAME];            
};
struct sockaddr_ctl {
	u_char      sc_len;     
	u_char      sc_family;  
	u_int16_t   ss_sysaddr; 
	u_int32_t   sc_id;      
	u_int32_t   sc_unit;    
	u_int32_t   sc_reserved[5];
};
#ifdef PRIVATE
struct xkctl_reg {
	u_int32_t       xkr_len;
	u_int32_t       xkr_kind;
	u_int32_t       xkr_id;
	u_int32_t       xkr_reg_unit;
	u_int32_t       xkr_flags;
	u_int64_t       xkr_kctlref;
	u_int32_t       xkr_recvbufsize;
	u_int32_t       xkr_sendbufsize;
	u_int32_t       xkr_lastunit;
	u_int32_t       xkr_pcbcount;
	u_int64_t       xkr_connect;
	u_int64_t       xkr_disconnect;
	u_int64_t       xkr_send;
	u_int64_t       xkr_send_list;
	u_int64_t       xkr_setopt;
	u_int64_t       xkr_getopt;
	u_int64_t       xkr_rcvd;
	char            xkr_name[MAX_KCTL_NAME];
};
struct xkctlpcb {
	u_int32_t       xkp_len;
	u_int32_t       xkp_kind;
	u_int64_t       xkp_kctpcb;
	u_int32_t       xkp_unit;
	u_int32_t       xkp_kctlid;
	u_int64_t       xkp_kctlref;
	char            xkp_kctlname[MAX_KCTL_NAME];
};
struct kctlstat {
	u_int64_t       kcs_reg_total __attribute__((aligned(8)));
	u_int64_t       kcs_reg_count __attribute__((aligned(8)));
	u_int64_t       kcs_pcbcount __attribute__((aligned(8)));
	u_int64_t       kcs_gencnt __attribute__((aligned(8)));
	u_int64_t       kcs_connections __attribute__((aligned(8)));
	u_int64_t       kcs_conn_fail __attribute__((aligned(8)));
	u_int64_t       kcs_send_fail __attribute__((aligned(8)));
	u_int64_t       kcs_send_list_fail __attribute__((aligned(8)));
	u_int64_t       kcs_enqueue_fail __attribute__((aligned(8)));
	u_int64_t       kcs_enqueue_fullsock __attribute__((aligned(8)));
	u_int64_t       kcs_bad_kctlref __attribute__((aligned(8)));
	u_int64_t       kcs_tbl_size_too_big __attribute__((aligned(8)));
	u_int64_t       kcs_enqdata_mb_alloc_fail __attribute__((aligned(8)));
	u_int64_t       kcs_enqdata_sbappend_fail __attribute__((aligned(8)));
};
#endif 
#ifdef KERNEL
#include <sys/kpi_mbuf.h>
typedef void * kern_ctl_ref;
#define CTL_FLAG_PRIVILEGED     0x1
#define CTL_FLAG_REG_ID_UNIT    0x2
#define CTL_FLAG_REG_SOCK_STREAM        0x4
#ifdef KERNEL_PRIVATE
#define CTL_FLAG_REG_EXTENDED   0x8
#define CTL_FLAG_REG_CRIT       0x10
#define CTL_FLAG_REG_SETUP      0x20
#endif 
#define CTL_DATA_NOWAKEUP       0x1
#define CTL_DATA_EOR            0x2
#ifdef KERNEL_PRIVATE
#define CTL_DATA_CRIT   0x4
#endif 
__BEGIN_DECLS
typedef errno_t (*ctl_connect_func)(kern_ctl_ref kctlref,
    struct sockaddr_ctl *sac,
    void **unitinfo);
typedef errno_t (*ctl_disconnect_func)(kern_ctl_ref kctlref, u_int32_t unit, void *unitinfo);
typedef errno_t (*ctl_send_func)(kern_ctl_ref kctlref, u_int32_t unit, void *unitinfo,
    mbuf_t m, int flags);
typedef errno_t (*ctl_setopt_func)(kern_ctl_ref kctlref, u_int32_t unit, void *unitinfo,
    int opt, void *data, size_t len);
typedef errno_t (*ctl_getopt_func)(kern_ctl_ref kctlref, u_int32_t unit, void *unitinfo,
    int opt, void *data, size_t *len);
#ifdef KERNEL_PRIVATE
typedef void (*ctl_rcvd_func)(kern_ctl_ref kctlref, u_int32_t unit, void *unitinfo,
    int flags);
typedef errno_t (*ctl_send_list_func)(kern_ctl_ref kctlref, u_int32_t unit, void *unitinfo,
    mbuf_t m, int flags);
typedef errno_t (*ctl_bind_func)(kern_ctl_ref kctlref,
    struct sockaddr_ctl *sac,
    void **unitinfo);
typedef errno_t (*ctl_setup_func)(u_int32_t *unit, void **unitinfo);
#endif 
struct kern_ctl_reg {
	char            ctl_name[MAX_KCTL_NAME];
	u_int32_t       ctl_id;
	u_int32_t       ctl_unit;
	u_int32_t   ctl_flags;
	u_int32_t   ctl_sendsize;
	u_int32_t   ctl_recvsize;
	ctl_connect_func    ctl_connect;
	ctl_disconnect_func ctl_disconnect;
	ctl_send_func               ctl_send;
	ctl_setopt_func             ctl_setopt;
	ctl_getopt_func             ctl_getopt;
#ifdef KERNEL_PRIVATE
	ctl_rcvd_func               ctl_rcvd;   
	ctl_send_list_func          ctl_send_list;
	ctl_bind_func           ctl_bind;
	ctl_setup_func                  ctl_setup;
#endif 
};
errno_t
ctl_register(struct kern_ctl_reg *userkctl, kern_ctl_ref *kctlref);
errno_t
ctl_deregister(kern_ctl_ref kctlref);
errno_t
ctl_enqueuedata(kern_ctl_ref kctlref, u_int32_t unit, void *data, size_t len, u_int32_t flags);
errno_t
ctl_enqueuembuf(kern_ctl_ref kctlref, u_int32_t unit, mbuf_t m, u_int32_t flags);
#ifdef PRIVATE
errno_t
ctl_enqueuembuf_list(kern_ctl_ref kctlref, u_int32_t unit, mbuf_t m_list,
    u_int32_t flags, mbuf_t *m_remain);
errno_t
ctl_getenqueuepacketcount(kern_ctl_ref kctlref, u_int32_t unit, u_int32_t *pcnt);
#endif 
errno_t
ctl_getenqueuespace(kern_ctl_ref kctlref, u_int32_t unit, size_t *space);
errno_t
ctl_getenqueuereadable(kern_ctl_ref kctlref, u_int32_t unit, u_int32_t *difference);
#ifdef KERNEL_PRIVATE
#include <sys/queue.h>
#include <libkern/locks.h>
struct ctl_cb;
struct kctl;
struct socket;
struct socket_info;
void kctl_fill_socketinfo(struct socket *, struct socket_info *);
u_int32_t ctl_id_by_name(const char *name);
errno_t ctl_name_by_id(u_int32_t id, char *out_name, size_t maxsize);
extern const u_int32_t ctl_maxunit;
#endif 
__END_DECLS
#endif 
#endif 