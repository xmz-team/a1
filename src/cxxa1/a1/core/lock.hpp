// lock.hpp
#pragma once
#include <string>
#include <fcntl.h>
#include <unistd.h>
#include <sys/file.h>
#include <flock-ios/flock.hpp>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>

namespace a1ctl {
class lock_manager {
private:
    int lock_fd = -1;
    std::string lock_file;
    bool lock_enabled = false;
public:
    lock_manager() = default;
    ~lock_manager() { release(); }
    void init(const std::string& file_path) { lock_file = file_path; }
    bool acquire() {
        if (!lock_enabled) return true;
        lock_fd = open(lock_file.c_str(), O_RDWR | O_CREAT | O_TRUNC, 0644);
        if (lock_fd < 0) {
            xmz::log::error("unable to open the lock file: ", lock_file);
            return false;
        }
        cleanup_stale_lock();
        int was_timeout = 0;
        int ret = flock_with_retry(lock_fd, LOCK_EX | LOCK_NB, 0, &was_timeout);
        if (ret < 0) {
            if (errno == EWOULDBLOCK || errno == EAGAIN) {
                std::string lock_pid = read_lock_pid();
                if (!lock_pid.empty()) {
                    xmz::log::error("process:", lock_pid, "holding lock, unable to continue the operation");
                    xmz::log::warn("you can choose to delete the lock file to continue the operation.");
                    xmz::log::warn("but! We don’t recommend using this method, unless the holding process is a zombie process, etc.");
                } else {
                    xmz::log::error("unable to get the lock");
                }
            } else {
                xmz::log::error("flock failed: ", strerror(errno));
            }
            close(lock_fd);
            lock_fd = -1;
            return false;
        }

        write_current_pid();
        return true;
    }
    void release() {
        if (lock_fd < 0) return;
        std::string lock_pid = read_lock_pid();
        pid_t current_pid = getpid();
        if (!lock_pid.empty()) {
            pid_t stored_pid = static_cast<pid_t>(std::stoi(lock_pid));
            if (stored_pid == current_pid) { unlink(lock_file.c_str()); }
        }
        int dummy_timeout;
        flock_with_retry(lock_fd, LOCK_UN, 0, &dummy_timeout);
        close(lock_fd);
        lock_fd = -1;
    }
    void set_enabled(bool enabled) { lock_enabled = enabled; }
    bool is_enabled() const { return lock_enabled; }
private:
    void cleanup_stale_lock() {
        std::string lock_pid = read_lock_pid();
        if (lock_pid.empty()) return;
        pid_t pid = static_cast<pid_t>(std::stoi(lock_pid));
        if (kill(pid, 0) != 0 && errno == ESRCH) {
            unlink(lock_file.c_str());
            xmz::log::info("the zombie lock has been cleaned up (the original holding process", pid, "no longer exists)");
        }
    }
    std::string read_lock_pid() {
        int fd = open(lock_file.c_str(), O_RDONLY);
        if (fd < 0) return "";
        char buffer[32] = {0};
        ssize_t n = read(fd, buffer, sizeof(buffer) - 1);
        close(fd);
        if (n <= 0) return "";
        buffer[n] = '\0';
        std::string pid(buffer);
        while (!pid.empty() && (pid.back() == '\n' || pid.back() == '\r')) { pid.pop_back(); }
        return pid;
    }
    void write_current_pid() {
        if (lock_fd < 0) return;
        ftruncate(lock_fd, 0);
        lseek(lock_fd, 0, SEEK_SET);
        std::string pid_str = std::to_string(getpid()) + "\n";
        write(lock_fd, pid_str.c_str(), pid_str.size());
        fsync(lock_fd);
    }
};

} // namespace a1ctl
