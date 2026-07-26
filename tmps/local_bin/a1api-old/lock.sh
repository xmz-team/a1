# lock.sh
# A1’s universal lock api
# You need to first define LOCK_FILE (the location of the lock file) and LOCK_FB (the lock fb)
_A1LockCoreFilePath=$( cd $(dirname ${BASH_SOURCE[0]} ) && pwd )
source "$_A1LockCoreFilePath/loadenv.sh"
_a1_init_env

cleanup_stale_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local old_pid
        old_pid="$(cat "$LOCK_FILE" 2>/dev/null)"
        if [ -z "$old_pid" ] || ! kill -0 "$old_pid" 2>/dev/null; then
            rm -f "$LOCK_FILE"
        fi
    fi
}

acquire_lock() {
    cleanup_stale_lock
    eval "exec $LOCK_FD>\"$LOCK_FILE\""
    if ! $flock -n $LOCK_FD; then
        local lock_pid
        lock_pid="$(cat "$LOCK_FILE" 2>/dev/null)"
        if [ -n "$lock_pid" ]; then
            cerr "${RED}[Error]${NC}: 进程 $lock_pid 正在持有 lock , 无法继续操作"
            cerr "${YELLOW}[Warn]${NC}: 你可以选择删除 lock 文件来让操作继续执行"
            cerr "${YELLOW}[Warn]${NC}: 但是!我们并不推荐使用此方法, 除非持有进程是僵尸进程等的情况"
        else
             cerr "${RED}[Error]${NC}: 无法获取到 lock"
        fi
        return 1
    fi
    echo "$$" > "$LOCK_FILE"
    return 0
}

release_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_pid
        lock_pid="$(cat "$LOCK_FILE" 2>/dev/null)"
        if [ "$lock_pid" = "$$" ]; then
            rm -f "$LOCK_FILE"
        fi
    fi
    eval "exec $LOCK_FD>&-"
}

export -f cleanup_stale_lock
export -f acquire_lock
export -f release_lock
