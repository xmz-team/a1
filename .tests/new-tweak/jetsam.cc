#include <sys/sysctl.h>

#define MEMORYSTATUS_CMD_SET_MEMLIMIT 4
extern int memorystatus_control(uint32_t command, pid_t pid, uint32_t flags, void *buffer, size_t buffersize);

bool setOtherProcessMemoryLimit(pid_t targetPid, long long memLimitBytes) {
    int ret = memorystatus_control(
        MEMORYSTATUS_CMD_SET_MEMLIMIT,
      targetPid, 
      0, 
      &memLimitBytes,
      sizeof(memLimitBytes)
    );
    if (ret != 0) {
        xmz::log::error("memorystatus_control failed");
        return false;
    }
    return true;
}
