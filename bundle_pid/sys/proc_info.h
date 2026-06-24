#ifndef _SYS_PROC_INFO_H
#define _SYS_PROC_INFO_H
#include <sys/cdefs.h>
#include <sys/param.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mount.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/kern_control.h>
#include <sys/event.h>
#include <net/if.h>
#include <net/route.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <mach/machine.h>
#include <uuid/uuid.h>
#ifdef PRIVATE
#include <mach/coalition.h> 
#endif
__BEGIN_DECLS
#define PROC_ALL_PIDS           1
#define PROC_PGRP_ONLY          2
#define PROC_TTY_ONLY           3
#define PROC_UID_ONLY           4
#define PROC_RUID_ONLY          5
#define PROC_PPID_ONLY          6
#define PROC_KDBG_ONLY          7
struct proc_bsdinfo {
	uint32_t                pbi_flags;              
	uint32_t                pbi_status;
	uint32_t                pbi_xstatus;
	uint32_t                pbi_pid;
	uint32_t                pbi_ppid;
	uid_t                   pbi_uid;
	gid_t                   pbi_gid;
	uid_t                   pbi_ruid;
	gid_t                   pbi_rgid;
	uid_t                   pbi_svuid;
	gid_t                   pbi_svgid;
	uint32_t                rfu_1;                  
	char                    pbi_comm[MAXCOMLEN];
	char                    pbi_name[2 * MAXCOMLEN];  
	uint32_t                pbi_nfiles;
	uint32_t                pbi_pgid;
	uint32_t                pbi_pjobc;
	uint32_t                e_tdev;                 
	uint32_t                e_tpgid;                
	int32_t                 pbi_nice;
	uint64_t                pbi_start_tvsec;
	uint64_t                pbi_start_tvusec;
};
struct proc_bsdshortinfo {
	uint32_t                pbsi_pid;               
	uint32_t                pbsi_ppid;              
	uint32_t                pbsi_pgid;              
	uint32_t                pbsi_status;            
	char                    pbsi_comm[MAXCOMLEN];   
	uint32_t                pbsi_flags;              
	uid_t                   pbsi_uid;               
	gid_t                   pbsi_gid;               
	uid_t                   pbsi_ruid;              
	gid_t                   pbsi_rgid;              
	uid_t                   pbsi_svuid;             
	gid_t                   pbsi_svgid;             
	uint32_t                pbsi_rfu;               
};
#ifdef  PRIVATE
struct proc_uniqidentifierinfo {
	uint8_t                 p_uuid[16];             
	uint64_t                p_uniqueid;             
	uint64_t                p_puniqueid;            
	int32_t                 p_idversion;            
	uint32_t                p_reserve2;             
	uint64_t                p_reserve3;             
	uint64_t                p_reserve4;             
};
struct proc_bsdinfowithuniqid {
	struct proc_bsdinfo             pbsd;
	struct proc_uniqidentifierinfo  p_uniqidentifier;
};
struct proc_archinfo {
	cpu_type_t              p_cputype;
	cpu_subtype_t           p_cpusubtype;
};
struct proc_pidcoalitioninfo {
	uint64_t coalition_id[COALITION_NUM_TYPES];
	uint64_t reserved1;
	uint64_t reserved2;
	uint64_t reserved3;
};
struct proc_originatorinfo {
	uuid_t                  originator_uuid;        
	pid_t                   originator_pid;         
	uint64_t                p_reserve2;
	uint64_t                p_reserve3;
	uint64_t                p_reserve4;
};
struct proc_ipctableinfo {
	uint32_t               table_size;
	uint32_t               table_free;
};
struct proc_threadschedinfo {
	uint64_t               int_time_ns;         
};
struct proc_threadcounts_data {
	uint64_t ptcd_instructions;
	uint64_t ptcd_cycles;
	uint64_t ptcd_user_time_mach;
	uint64_t ptcd_system_time_mach;
	uint64_t ptcd_energy_nj;
};
struct proc_threadcounts {
	uint16_t ptc_len;
	uint16_t ptc_reserved0;
	uint32_t ptc_reserved1;
	struct proc_threadcounts_data ptc_counts[];
};
#endif 
#define PROC_FLAG_SYSTEM        1       
#define PROC_FLAG_TRACED        2       
#define PROC_FLAG_INEXIT        4       
#define PROC_FLAG_PPWAIT        8
#define PROC_FLAG_LP64          0x10    
#define PROC_FLAG_SLEADER       0x20    
#define PROC_FLAG_CTTY          0x40    
#define PROC_FLAG_CONTROLT      0x80    
#define PROC_FLAG_THCWD         0x100   
#define PROC_FLAG_PC_THROTTLE   0x200   
#define PROC_FLAG_PC_SUSP       0x400   
#define PROC_FLAG_PC_KILL       0x600   
#define PROC_FLAG_PC_MASK       0x600
#define PROC_FLAG_PA_THROTTLE   0x800   
#define PROC_FLAG_PA_SUSP       0x1000  
#define PROC_FLAG_PSUGID        0x2000   
#define PROC_FLAG_EXEC          0x4000   
#ifdef  PRIVATE
#define PROC_FLAG_DARWINBG      0x8000  
#define PROC_FLAG_EXT_DARWINBG  0x10000 
#define PROC_FLAG_IOS_APPLEDAEMON 0x20000       
#define PROC_FLAG_DELAYIDLESLEEP 0x40000        
#define PROC_FLAG_IOS_IMPPROMOTION 0x80000      
#define PROC_FLAG_ADAPTIVE              0x100000         
#define PROC_FLAG_ADAPTIVE_IMPORTANT    0x200000         
#define PROC_FLAG_IMPORTANCE_DONOR   0x400000 
#define PROC_FLAG_SUPPRESSED         0x800000 
#define PROC_FLAG_APPLICATION 0x1000000 
#define PROC_FLAG_IOS_APPLICATION PROC_FLAG_APPLICATION 
#define PROC_FLAG_ROSETTA 0x2000000 
#endif
struct proc_taskinfo {
	uint64_t                pti_virtual_size;       
	uint64_t                pti_resident_size;      
	uint64_t                pti_total_user;         
	uint64_t                pti_total_system;
	uint64_t                pti_threads_user;       
	uint64_t                pti_threads_system;
	int32_t                 pti_policy;             
	int32_t                 pti_faults;             
	int32_t                 pti_pageins;            
	int32_t                 pti_cow_faults;         
	int32_t                 pti_messages_sent;      
	int32_t                 pti_messages_received;  
	int32_t                 pti_syscalls_mach;      
	int32_t                 pti_syscalls_unix;      
	int32_t                 pti_csw;                
	int32_t                 pti_threadnum;          
	int32_t                 pti_numrunning;         
	int32_t                 pti_priority;           
};
struct proc_taskallinfo {
	struct proc_bsdinfo     pbsd;
	struct proc_taskinfo    ptinfo;
};
#define MAXTHREADNAMESIZE 64
struct proc_threadinfo {
	uint64_t                pth_user_time;          
	uint64_t                pth_system_time;        
	int32_t                 pth_cpu_usage;          
	int32_t                 pth_policy;             
	int32_t                 pth_run_state;          
	int32_t                 pth_flags;              
	int32_t                 pth_sleep_time;         
	int32_t                 pth_curpri;             
	int32_t                 pth_priority;           
	int32_t                 pth_maxpriority;        
	char                    pth_name[MAXTHREADNAMESIZE];    
};
struct proc_regioninfo {
	uint32_t                pri_protection;
	uint32_t                pri_max_protection;
	uint32_t                pri_inheritance;
	uint32_t                pri_flags;              
	uint64_t                pri_offset;
	uint32_t                pri_behavior;
	uint32_t                pri_user_wired_count;
	uint32_t                pri_user_tag;
	uint32_t                pri_pages_resident;
	uint32_t                pri_pages_shared_now_private;
	uint32_t                pri_pages_swapped_out;
	uint32_t                pri_pages_dirtied;
	uint32_t                pri_ref_count;
	uint32_t                pri_shadow_depth;
	uint32_t                pri_share_mode;
	uint32_t                pri_private_pages_resident;
	uint32_t                pri_shared_pages_resident;
	uint32_t                pri_obj_id;
	uint32_t                pri_depth;
	uint64_t                pri_address;
	uint64_t                pri_size;
};
#define PROC_REGION_SUBMAP      1
#define PROC_REGION_SHARED      2
#define SM_COW             1
#define SM_PRIVATE         2
#define SM_EMPTY           3
#define SM_SHARED          4
#define SM_TRUESHARED      5
#define SM_PRIVATE_ALIASED 6
#define SM_SHARED_ALIASED  7
#define SM_LARGE_PAGE      8
#define TH_STATE_RUNNING        1       
#define TH_STATE_STOPPED        2       
#define TH_STATE_WAITING        3       
#define TH_STATE_UNINTERRUPTIBLE 4      
#define TH_STATE_HALTED         5       
#define TH_FLAGS_SWAPPED        0x1     
#define TH_FLAGS_IDLE           0x2     
struct proc_workqueueinfo {
	uint32_t        pwq_nthreads;           
	uint32_t        pwq_runthreads;         
	uint32_t        pwq_blockedthreads;     
	uint32_t        pwq_state;
};
#define WQ_EXCEEDED_CONSTRAINED_THREAD_LIMIT 0x1
#define WQ_EXCEEDED_TOTAL_THREAD_LIMIT 0x2
#define WQ_FLAGS_AVAILABLE 0x4
struct proc_fileinfo {
	uint32_t                fi_openflags;
	uint32_t                fi_status;
	off_t                   fi_offset;
	int32_t                 fi_type;
	uint32_t                fi_guardflags;
};
#define PROC_FP_SHARED  1       
#define PROC_FP_CLEXEC  2       
#define PROC_FP_GUARDED 4       
#define PROC_FP_CLFORK  8       
#define PROC_FI_GUARD_CLOSE             (1u << 0)
#define PROC_FI_GUARD_DUP               (1u << 1)
#define PROC_FI_GUARD_SOCKET_IPC        (1u << 2)
#define PROC_FI_GUARD_FILEPORT          (1u << 3)
struct proc_exitreasonbasicinfo {
	uint32_t                        beri_namespace;
	uint64_t                        beri_code;
	uint64_t                        beri_flags;
	uint32_t                        beri_reason_buf_size;
} __attribute__((packed));
struct proc_exitreasoninfo {
	uint32_t                        eri_namespace;
	uint64_t                        eri_code;
	uint64_t                        eri_flags;
	uint32_t                        eri_reason_buf_size;
	uint64_t                        eri_kcd_buf;
} __attribute__((packed));
struct vinfo_stat {
	uint32_t        vst_dev;        
	uint16_t        vst_mode;       
	uint16_t        vst_nlink;      
	uint64_t        vst_ino;        
	uid_t           vst_uid;        
	gid_t           vst_gid;        
	int64_t         vst_atime;      
	int64_t         vst_atimensec;  
	int64_t         vst_mtime;      
	int64_t         vst_mtimensec;  
	int64_t         vst_ctime;      
	int64_t         vst_ctimensec;  
	int64_t         vst_birthtime;  
	int64_t         vst_birthtimensec;      
	off_t           vst_size;       
	int64_t         vst_blocks;     
	int32_t         vst_blksize;    
	uint32_t        vst_flags;      
	uint32_t        vst_gen;        
	uint32_t        vst_rdev;       
	int64_t         vst_qspare[2];  
};
struct vnode_info {
	struct vinfo_stat       vi_stat;
	int                     vi_type;
	int                     vi_pad;
	fsid_t                  vi_fsid;
};
struct vnode_info_path {
	struct vnode_info       vip_vi;
	char                    vip_path[MAXPATHLEN];   
};
struct vnode_fdinfo {
	struct proc_fileinfo    pfi;
	struct vnode_info       pvi;
};
struct vnode_fdinfowithpath {
	struct proc_fileinfo    pfi;
	struct vnode_info_path  pvip;
};
struct proc_regionwithpathinfo {
	struct proc_regioninfo  prp_prinfo;
	struct vnode_info_path  prp_vip;
};
struct proc_regionpath {
	uint64_t prpo_addr;
	uint64_t prpo_regionlength;
	char prpo_path[MAXPATHLEN];
};
struct proc_vnodepathinfo {
	struct vnode_info_path  pvi_cdir;
	struct vnode_info_path  pvi_rdir;
};
struct proc_threadwithpathinfo {
	struct proc_threadinfo  pt;
	struct vnode_info_path  pvip;
};
#define INI_IPV4        0x1
#define INI_IPV6        0x2
struct in4in6_addr {
	u_int32_t               i46a_pad32[3];
	struct in_addr          i46a_addr4;
};
struct in_sockinfo {
	int                                     insi_fport;             
	int                                     insi_lport;             
	uint64_t                                insi_gencnt;            
	uint32_t                                insi_flags;             
	uint32_t                                insi_flow;
	uint8_t                                 insi_vflag;             
	uint8_t                                 insi_ip_ttl;            
	uint32_t                                rfu_1;                  
	union {
		struct in4in6_addr      ina_46;
		struct in6_addr         ina_6;
	}                                       insi_faddr;             
	union {
		struct in4in6_addr      ina_46;
		struct in6_addr         ina_6;
	}                                       insi_laddr;             
	struct {
		u_char                  in4_tos;                        
	}                                       insi_v4;
	struct {
		uint8_t                 in6_hlim;
		int                     in6_cksum;
		u_short                 in6_ifindex;
		short                   in6_hops;
	}                                       insi_v6;
};
#define TSI_T_REXMT             0       
#define TSI_T_PERSIST           1       
#define TSI_T_KEEP              2       
#define TSI_T_2MSL              3       
#define TSI_T_NTIMERS           4
#define TSI_S_CLOSED            0       
#define TSI_S_LISTEN            1       
#define TSI_S_SYN_SENT          2       
#define TSI_S_SYN_RECEIVED      3       
#define TSI_S_ESTABLISHED       4       
#define TSI_S__CLOSE_WAIT       5       
#define TSI_S_FIN_WAIT_1        6       
#define TSI_S_CLOSING           7       
#define TSI_S_LAST_ACK          8       
#define TSI_S_FIN_WAIT_2        9       
#define TSI_S_TIME_WAIT         10      
#define TSI_S_RESERVED          11      
struct tcp_sockinfo {
	struct in_sockinfo              tcpsi_ini;
	int                             tcpsi_state;
	int                             tcpsi_timer[TSI_T_NTIMERS];
	int                             tcpsi_mss;
	uint32_t                        tcpsi_flags;
	uint32_t                        rfu_1;          
	uint64_t                        tcpsi_tp;       
};
struct un_sockinfo {
	uint64_t                                unsi_conn_so;   
	uint64_t                                unsi_conn_pcb;  
	union {
		struct sockaddr_un      ua_sun;
		char                    ua_dummy[SOCK_MAXADDRLEN];
	}                                       unsi_addr;      
	union {
		struct sockaddr_un      ua_sun;
		char                    ua_dummy[SOCK_MAXADDRLEN];
	}                                       unsi_caddr;     
};
struct ndrv_info {
	uint32_t        ndrvsi_if_family;
	uint32_t        ndrvsi_if_unit;
	char            ndrvsi_if_name[IF_NAMESIZE];
};
struct kern_event_info {
	uint32_t        kesi_vendor_code_filter;
	uint32_t        kesi_class_filter;
	uint32_t        kesi_subclass_filter;
};
struct kern_ctl_info {
	uint32_t        kcsi_id;
	uint32_t        kcsi_reg_unit;
	uint32_t        kcsi_flags;                     
	uint32_t        kcsi_recvbufsize;               
	uint32_t        kcsi_sendbufsize;               
	uint32_t        kcsi_unit;
	char            kcsi_name[MAX_KCTL_NAME];       
};
struct vsock_sockinfo {
	uint32_t        local_cid;
	uint32_t        local_port;
	uint32_t        remote_cid;
	uint32_t        remote_port;
};
#define SOI_S_NOFDREF           0x0001  
#define SOI_S_ISCONNECTED       0x0002  
#define SOI_S_ISCONNECTING      0x0004  
#define SOI_S_ISDISCONNECTING   0x0008  
#define SOI_S_CANTSENDMORE      0x0010  
#define SOI_S_CANTRCVMORE       0x0020  
#define SOI_S_RCVATMARK         0x0040  
#define SOI_S_PRIV              0x0080  
#define SOI_S_NBIO              0x0100  
#define SOI_S_ASYNC             0x0200  
#define SOI_S_INCOMP            0x0800  
#define SOI_S_COMP              0x1000  
#define SOI_S_ISDISCONNECTED    0x2000  
#define SOI_S_DRAINING          0x4000  
struct sockbuf_info {
	uint32_t                sbi_cc;
	uint32_t                sbi_hiwat;                      
	uint32_t                sbi_mbcnt;
	uint32_t                sbi_mbmax;
	uint32_t                sbi_lowat;
	short                   sbi_flags;
	short                   sbi_timeo;
};
enum {
	SOCKINFO_GENERIC        = 0,
	SOCKINFO_IN             = 1,
	SOCKINFO_TCP            = 2,
	SOCKINFO_UN             = 3,
	SOCKINFO_NDRV           = 4,
	SOCKINFO_KERN_EVENT     = 5,
	SOCKINFO_KERN_CTL       = 6,
	SOCKINFO_VSOCK          = 7,
};
struct socket_info {
	struct vinfo_stat                       soi_stat;
	uint64_t                                soi_so;         
	uint64_t                                soi_pcb;        
	int                                     soi_type;
	int                                     soi_protocol;
	int                                     soi_family;
	short                                   soi_options;
	short                                   soi_linger;
	short                                   soi_state;
	short                                   soi_qlen;
	short                                   soi_incqlen;
	short                                   soi_qlimit;
	short                                   soi_timeo;
	u_short                                 soi_error;
	uint32_t                                soi_oobmark;
	struct sockbuf_info                     soi_rcv;
	struct sockbuf_info                     soi_snd;
	int                                     soi_kind;
	uint32_t                                rfu_1;          
	union {
		struct in_sockinfo      pri_in;                 
		struct tcp_sockinfo     pri_tcp;                
		struct un_sockinfo      pri_un;                 
		struct ndrv_info        pri_ndrv;               
		struct kern_event_info  pri_kern_event;         
		struct kern_ctl_info    pri_kern_ctl;           
		struct vsock_sockinfo   pri_vsock;              
	}                                       soi_proto;
};
struct socket_fdinfo {
	struct proc_fileinfo    pfi;
	struct socket_info      psi;
};
struct psem_info {
	struct vinfo_stat       psem_stat;
	char                    psem_name[MAXPATHLEN];
};
struct psem_fdinfo {
	struct proc_fileinfo    pfi;
	struct psem_info        pseminfo;
};
struct pshm_info  {
	struct vinfo_stat       pshm_stat;
	uint64_t                pshm_mappaddr;
	char                    pshm_name[MAXPATHLEN];
};
struct pshm_fdinfo {
	struct proc_fileinfo    pfi;
	struct pshm_info        pshminfo;
};
struct pipe_info {
	struct vinfo_stat       pipe_stat;
	uint64_t                pipe_handle;
	uint64_t                pipe_peerhandle;
	int                     pipe_status;
	int                     rfu_1;  
};
struct pipe_fdinfo {
	struct proc_fileinfo    pfi;
	struct pipe_info        pipeinfo;
};
struct kqueue_info {
	struct vinfo_stat       kq_stat;
	uint32_t                kq_state;
	uint32_t                rfu_1;  
};
struct kqueue_dyninfo {
	struct kqueue_info kqdi_info;
	uint64_t kqdi_servicer;
	uint64_t kqdi_owner;
	uint32_t kqdi_sync_waiters;
	uint8_t  kqdi_sync_waiter_qos;
	uint8_t  kqdi_async_qos;
	uint16_t kqdi_request_state;
	uint8_t  kqdi_events_qos;
	uint8_t  kqdi_pri;
	uint8_t  kqdi_pol;
	uint8_t  kqdi_cpupercent;
	uint8_t  _kqdi_reserved0[4];
	uint64_t _kqdi_reserved1[4];
};
#define PROC_KQUEUE_SELECT      0x0001
#define PROC_KQUEUE_SLEEP       0x0002
#define PROC_KQUEUE_32          0x0008
#define PROC_KQUEUE_64          0x0010
#define PROC_KQUEUE_QOS         0x0020
#ifdef PRIVATE
#define PROC_KQUEUE_WORKQ       0x0040
#define PROC_KQUEUE_WORKLOOP    0x0080
struct kevent_extinfo {
	struct kevent_qos_s kqext_kev;
	uint64_t kqext_sdata;
	int kqext_status;
	int kqext_sfflags;
	uint64_t kqext_reserved[2];
};
#endif 
struct kqueue_fdinfo {
	struct proc_fileinfo    pfi;
	struct kqueue_info      kqueueinfo;
};
struct appletalk_info {
	struct vinfo_stat       atalk_stat;
};
struct appletalk_fdinfo {
	struct proc_fileinfo    pfi;
	struct appletalk_info   appletalkinfo;
};
typedef uint64_t proc_info_udata_t;
#define PROX_FDTYPE_ATALK       0
#define PROX_FDTYPE_VNODE       1
#define PROX_FDTYPE_SOCKET      2
#define PROX_FDTYPE_PSHM        3
#define PROX_FDTYPE_PSEM        4
#define PROX_FDTYPE_KQUEUE      5
#define PROX_FDTYPE_PIPE        6
#define PROX_FDTYPE_FSEVENTS    7
#define PROX_FDTYPE_NETPOLICY   9
#define PROX_FDTYPE_CHANNEL     10
#define PROX_FDTYPE_NEXUS       11
struct proc_fdinfo {
	int32_t                 proc_fd;
	uint32_t                proc_fdtype;
};
struct proc_fileportinfo {
	uint32_t                proc_fileport;
	uint32_t                proc_fdtype;
};
#define PROC_CHANNEL_TYPE_USER_PIPE             0
#define PROC_CHANNEL_TYPE_KERNEL_PIPE           1
#define PROC_CHANNEL_TYPE_NET_IF                2
#define PROC_CHANNEL_TYPE_FLOW_SWITCH           3
#define PROC_CHANNEL_FLAGS_MONITOR_TX           0x1
#define PROC_CHANNEL_FLAGS_MONITOR_RX           0x2
#define PROC_CHANNEL_FLAGS_MONITOR_NO_COPY      0x4
#define PROC_CHANNEL_FLAGS_EXCLUSIVE            0x10
#define PROC_CHANNEL_FLAGS_USER_PACKET_POOL     0x20
#define PROC_CHANNEL_FLAGS_DEFUNCT_OK           0x40
#define PROC_CHANNEL_FLAGS_LOW_LATENCY          0x80
#define PROC_CHANNEL_FLAGS_MONITOR                                      \
	(PROC_CHANNEL_FLAGS_MONITOR_TX | PROC_CHANNEL_FLAGS_MONITOR_RX)
struct proc_channel_info {
	uuid_t                  chi_instance;
	uint32_t                chi_port;
	uint32_t                chi_type;
	uint32_t                chi_flags;
	uint32_t                rfu_1;
};
struct channel_fdinfo {
	struct proc_fileinfo    pfi;
	struct proc_channel_info channelinfo;
};
#define PROC_PIDLISTFDS                 1
#define PROC_PIDLISTFD_SIZE             (sizeof(struct proc_fdinfo))
#define PROC_PIDTASKALLINFO             2
#define PROC_PIDTASKALLINFO_SIZE        (sizeof(struct proc_taskallinfo))
#define PROC_PIDTBSDINFO                3
#define PROC_PIDTBSDINFO_SIZE           (sizeof(struct proc_bsdinfo))
#define PROC_PIDTASKINFO                4
#define PROC_PIDTASKINFO_SIZE           (sizeof(struct proc_taskinfo))
#define PROC_PIDTHREADINFO              5
#define PROC_PIDTHREADINFO_SIZE         (sizeof(struct proc_threadinfo))
#define PROC_PIDLISTTHREADS             6
#define PROC_PIDLISTTHREADS_SIZE        (2* sizeof(uint32_t))
#define PROC_PIDREGIONINFO              7
#define PROC_PIDREGIONINFO_SIZE         (sizeof(struct proc_regioninfo))
#define PROC_PIDREGIONPATHINFO          8
#define PROC_PIDREGIONPATHINFO_SIZE     (sizeof(struct proc_regionwithpathinfo))
#define PROC_PIDVNODEPATHINFO           9
#define PROC_PIDVNODEPATHINFO_SIZE      (sizeof(struct proc_vnodepathinfo))
#define PROC_PIDTHREADPATHINFO          10
#define PROC_PIDTHREADPATHINFO_SIZE     (sizeof(struct proc_threadwithpathinfo))
#define PROC_PIDPATHINFO                11
#define PROC_PIDPATHINFO_SIZE           (MAXPATHLEN)
#define PROC_PIDPATHINFO_MAXSIZE        (4*MAXPATHLEN)
#define PROC_PIDWORKQUEUEINFO           12
#define PROC_PIDWORKQUEUEINFO_SIZE      (sizeof(struct proc_workqueueinfo))
#define PROC_PIDT_SHORTBSDINFO          13
#define PROC_PIDT_SHORTBSDINFO_SIZE     (sizeof(struct proc_bsdshortinfo))
#define PROC_PIDLISTFILEPORTS           14
#define PROC_PIDLISTFILEPORTS_SIZE      (sizeof(struct proc_fileportinfo))
#define PROC_PIDTHREADID64INFO          15
#define PROC_PIDTHREADID64INFO_SIZE     (sizeof(struct proc_threadinfo))
#define PROC_PID_RUSAGE                 16
#define PROC_PID_RUSAGE_SIZE            0
#ifdef  PRIVATE
#define PROC_PIDUNIQIDENTIFIERINFO      17
#define PROC_PIDUNIQIDENTIFIERINFO_SIZE \
	                                (sizeof(struct proc_uniqidentifierinfo))
#define PROC_PIDT_BSDINFOWITHUNIQID     18
#define PROC_PIDT_BSDINFOWITHUNIQID_SIZE \
	                                (sizeof(struct proc_bsdinfowithuniqid))
#define PROC_PIDARCHINFO                19
#define PROC_PIDARCHINFO_SIZE           \
	                                (sizeof(struct proc_archinfo))
#define PROC_PIDCOALITIONINFO           20
#define PROC_PIDCOALITIONINFO_SIZE      (sizeof(struct proc_pidcoalitioninfo))
#define PROC_PIDNOTEEXIT                21
#define PROC_PIDNOTEEXIT_SIZE           (sizeof(uint32_t))
#define PROC_PIDREGIONPATHINFO2         22
#define PROC_PIDREGIONPATHINFO2_SIZE    (sizeof(struct proc_regionwithpathinfo))
#define PROC_PIDREGIONPATHINFO3         23
#define PROC_PIDREGIONPATHINFO3_SIZE    (sizeof(struct proc_regionwithpathinfo))
#define PROC_PIDEXITREASONINFO          24
#define PROC_PIDEXITREASONINFO_SIZE     (sizeof(struct proc_exitreasoninfo))
#define PROC_PIDEXITREASONBASICINFO     25
#define PROC_PIDEXITREASONBASICINFOSIZE (sizeof(struct proc_exitreasonbasicinfo))
#define PROC_PIDLISTUPTRS      26
#define PROC_PIDLISTUPTRS_SIZE (sizeof(uint64_t))
#define PROC_PIDLISTDYNKQUEUES      27
#define PROC_PIDLISTDYNKQUEUES_SIZE (sizeof(kqueue_id_t))
#define PROC_PIDLISTTHREADIDS           28
#define PROC_PIDLISTTHREADIDS_SIZE      (2* sizeof(uint32_t))
#define PROC_PIDVMRTFAULTINFO           29
#define PROC_PIDVMRTFAULTINFO_SIZE (7 * sizeof(uint64_t))
#define PROC_PIDPLATFORMINFO 30
#define PROC_PIDPLATFORMINFO_SIZE (sizeof(uint32_t))
#define PROC_PIDREGIONPATH              31
#define PROC_PIDREGIONPATH_SIZE         (sizeof(struct proc_regionpath))
#define PROC_PIDIPCTABLEINFO 32
#define PROC_PIDIPCTABLEINFO_SIZE (sizeof(struct proc_ipctableinfo))
#define PROC_PIDTHREADSCHEDINFO 33
#define PROC_PIDTHREADSCHEDINFO_SIZE (sizeof(struct proc_threadschedinfo))
#define PROC_PIDTHREADCOUNTS 34
#define PROC_PIDTHREADCOUNTS_SIZE (sizeof(struct proc_threadcounts))
#endif 
#define PROC_PIDFDVNODEINFO             1
#define PROC_PIDFDVNODEINFO_SIZE        (sizeof(struct vnode_fdinfo))
#define PROC_PIDFDVNODEPATHINFO         2
#define PROC_PIDFDVNODEPATHINFO_SIZE    (sizeof(struct vnode_fdinfowithpath))
#define PROC_PIDFDSOCKETINFO            3
#define PROC_PIDFDSOCKETINFO_SIZE       (sizeof(struct socket_fdinfo))
#define PROC_PIDFDPSEMINFO              4
#define PROC_PIDFDPSEMINFO_SIZE         (sizeof(struct psem_fdinfo))
#define PROC_PIDFDPSHMINFO              5
#define PROC_PIDFDPSHMINFO_SIZE         (sizeof(struct pshm_fdinfo))
#define PROC_PIDFDPIPEINFO              6
#define PROC_PIDFDPIPEINFO_SIZE         (sizeof(struct pipe_fdinfo))
#define PROC_PIDFDKQUEUEINFO            7
#define PROC_PIDFDKQUEUEINFO_SIZE       (sizeof(struct kqueue_fdinfo))
#define PROC_PIDFDATALKINFO             8
#define PROC_PIDFDATALKINFO_SIZE        (sizeof(struct appletalk_fdinfo))
#ifdef PRIVATE
#define PROC_PIDFDKQUEUE_EXTINFO        9
#define PROC_PIDFDKQUEUE_EXTINFO_SIZE   (sizeof(struct kevent_extinfo))
#define PROC_PIDFDKQUEUE_KNOTES_MAX     (1024 * 128)
#define PROC_PIDDYNKQUEUES_MAX  (1024 * 128)
#endif 
#define PROC_PIDFDCHANNELINFO           10
#define PROC_PIDFDCHANNELINFO_SIZE      (sizeof(struct channel_fdinfo))
#define PROC_PIDFILEPORTVNODEPATHINFO   2       
#define PROC_PIDFILEPORTVNODEPATHINFO_SIZE      \
	                                PROC_PIDFDVNODEPATHINFO_SIZE
#define PROC_PIDFILEPORTSOCKETINFO      3       
#define PROC_PIDFILEPORTSOCKETINFO_SIZE PROC_PIDFDSOCKETINFO_SIZE
#define PROC_PIDFILEPORTPSHMINFO        5       
#define PROC_PIDFILEPORTPSHMINFO_SIZE   PROC_PIDFDPSHMINFO_SIZE
#define PROC_PIDFILEPORTPIPEINFO        6       
#define PROC_PIDFILEPORTPIPEINFO_SIZE   PROC_PIDFDPIPEINFO_SIZE
#define PROC_SELFSET_PCONTROL           1
#define PROC_SELFSET_THREADNAME         2
#define PROC_SELFSET_THREADNAME_SIZE    (MAXTHREADNAMESIZE -1)
#define PROC_SELFSET_VMRSRCOWNER        3
#define PROC_SELFSET_DELAYIDLESLEEP     4
#define PROC_DIRTYCONTROL_TRACK         1
#define PROC_DIRTYCONTROL_SET           2
#define PROC_DIRTYCONTROL_GET           3
#define PROC_DIRTYCONTROL_CLEAR         4
#define PROC_DIRTY_TRACK                0x1
#define PROC_DIRTY_ALLOW_IDLE_EXIT      0x2
#define PROC_DIRTY_DEFER                0x4
#define PROC_DIRTY_LAUNCH_IN_PROGRESS   0x8
#define PROC_DIRTY_DEFER_ALWAYS         0x10
#define PROC_DIRTY_TRACKED              0x1
#define PROC_DIRTY_ALLOWS_IDLE_EXIT     0x2
#define PROC_DIRTY_IS_DIRTY             0x4
#define PROC_DIRTY_LAUNCH_IS_IN_PROGRESS   0x8
#define PROC_UDATA_INFO_GET             1
#define PROC_UDATA_INFO_SET             2
#ifdef PRIVATE
#define PROC_PIDORIGINATOR_UUID         0x1
#define PROC_PIDORIGINATOR_UUID_SIZE    (sizeof(uuid_t))
#define PROC_PIDORIGINATOR_BGSTATE      0x2
#define PROC_PIDORIGINATOR_BGSTATE_SIZE (sizeof(uint32_t))
#define PROC_PIDORIGINATOR_PID_UUID     0x3
#define PROC_PIDORIGINATOR_PID_UUID_SIZE (sizeof(struct proc_originatorinfo))
#define LISTCOALITIONS_ALL_COALS        1
#define LISTCOALITIONS_ALL_COALS_SIZE   (sizeof(struct procinfo_coalinfo))
#define LISTCOALITIONS_SINGLE_TYPE      2
#define LISTCOALITIONS_SINGLE_TYPE_SIZE (sizeof(struct procinfo_coalinfo))
#define PROC_FGHW_OK                     0 
#define PROC_FGHW_DAEMON_OK              1
#define PROC_FGHW_DAEMON_LEADER         10 
#define PROC_FGHW_LEADER_NONUI          11 
#define PROC_FGHW_LEADER_BACKGROUND     12 
#define PROC_FGHW_DAEMON_NO_VOUCHER     13 
#define PROC_FGHW_NO_VOUCHER_ATTR       14 
#define PROC_FGHW_NO_ORIGINATOR         15 
#define PROC_FGHW_ORIGINATOR_BACKGROUND 16 
#define PROC_FGHW_VOUCHER_ERROR         98 
#define PROC_FGHW_ERROR                 99 
#define PROC_PIDDYNKQUEUE_INFO         0
#define PROC_PIDDYNKQUEUE_INFO_SIZE    (sizeof(struct kqueue_dyninfo))
#define PROC_PIDDYNKQUEUE_EXTINFO      1
#define PROC_PIDDYNKQUEUE_EXTINFO_SIZE (sizeof(struct kevent_extinfo))
#define PROC_INFO_CALL_LISTPIDS          0x1
#define PROC_INFO_CALL_PIDINFO           0x2
#define PROC_INFO_CALL_PIDFDINFO         0x3
#define PROC_INFO_CALL_KERNMSGBUF        0x4
#define PROC_INFO_CALL_SETCONTROL        0x5
#define PROC_INFO_CALL_PIDFILEPORTINFO   0x6
#define PROC_INFO_CALL_TERMINATE         0x7
#define PROC_INFO_CALL_DIRTYCONTROL      0x8
#define PROC_INFO_CALL_PIDRUSAGE         0x9
#define PROC_INFO_CALL_PIDORIGINATORINFO 0xa
#define PROC_INFO_CALL_LISTCOALITIONS    0xb
#define PROC_INFO_CALL_CANUSEFGHW        0xc
#define PROC_INFO_CALL_PIDDYNKQUEUEINFO  0xd
#define PROC_INFO_CALL_UDATA_INFO        0xe
#define PROC_INFO_CALL_SET_DYLD_IMAGES   0xf
#define PROC_INFO_CALL_TERMINATE_RSR     0x10
#define PIF_COMPARE_IDVERSION           0x01
#define PIF_COMPARE_UNIQUEID            0x02
#endif 
#ifdef KERNEL_PRIVATE
extern int proc_fdlist(proc_t p, struct proc_fdinfo *buf, size_t *count);
#endif
#ifdef XNU_KERNEL_PRIVATE
#ifndef pshmnode
struct pshmnode;
#endif
#ifndef psemnode
struct psemnode;
#endif
#ifndef pipe
struct pipe;
#endif
extern int fill_socketinfo(socket_t so, struct socket_info *si);
extern int fill_pshminfo(struct pshmnode * pshm, struct pshm_info * pinfo);
extern int fill_pseminfo(struct psemnode * psem, struct psem_info * pinfo);
extern int fill_pipeinfo(struct pipe * cpipe, struct pipe_info * pinfo);
extern int fill_kqueueinfo(struct kqueue * kq, struct kqueue_info * kinfo);
extern int pid_kqueue_extinfo(proc_t, struct kqueue * kq, user_addr_t buffer,
    uint32_t buffersize, int32_t * retval);
extern int pid_kqueue_udatainfo(proc_t p, struct kqueue *kq, uint64_t *buf,
    uint32_t bufsize);
extern int pid_kqueue_listdynamickqueues(proc_t p, user_addr_t ubuf,
    uint32_t bufsize, int32_t *retval);
extern int pid_dynamickqueue_extinfo(proc_t p, kqueue_id_t kq_id,
    user_addr_t ubuf, uint32_t bufsize, int32_t *retval);
struct kern_channel;
extern int fill_channelinfo(struct kern_channel * chan,
    struct proc_channel_info *chan_info);
extern int fill_procworkqueue(proc_t, struct proc_workqueueinfo *);
extern boolean_t workqueue_get_pwq_exceeded(void *v, boolean_t *exceeded_total,
    boolean_t *exceeded_constrained);
extern uint32_t workqueue_get_pwq_state_kdp(void *proc);
#endif 
__END_DECLS
#endif 