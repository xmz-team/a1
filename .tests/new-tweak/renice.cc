#include <sys/resource.h>

bool setOtherProcessNice(pid_t targetPid, int niceValue) {
    // nice value: -20~19，Negative number need root
    if (setpriority(PRIO_PROCESS, targetPid, niceValue) == -1) {
        perror("setpriority failed");
        return false;
    }
    return true;
}
