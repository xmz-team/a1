// env.h
#ifndef A1_ENV_H
#define A1_ENV_H
#include "cfg.h"
#include <dlfcn.h>
#include <string>
#include <vector>
#include <unistd.h>
#include <sys/wait.h>
#include <cstdio>
#include <cstring>
#include <cstdlib>

#import <Foundation/Foundation.h>

#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>

#include <a1/core/config.hpp>

inline a1::config::jb_path g_jb;

namespace a1gui {
class env {
private:
    std::string _get_self_path() {
        @autoreleasepool {
            NSString *path = [[NSBundle mainBundle] bundlePath];
            return std::string([path UTF8String]);
        }
    }
    std::string _get_jb_env() {
        auto run_capture = [&](char *const argv[], char *buf, size_t cap) -> int {
            int pipefd[2];
            if (pipe(pipefd) == -1) {
                perror("pipe");
                return -1;
            }
            pid_t pid = fork();
            if (pid == -1) {
                perror("fork");
                close(pipefd[0]);
                close(pipefd[1]);
                return -1;
            }
            if (pid == 0) {
                close(pipefd[0]);
                dup2(pipefd[1], STDOUT_FILENO);
                close(pipefd[1]);
                execvp(argv[0], argv);
                perror("execvp");
                _exit(127);
            }
            close(pipefd[1]);
            size_t used = 0;
            ssize_t n;
            while ((n = read(pipefd[0], buf + used, cap - 1 - used)) > 0) {
                used += (size_t)n;
                if (used >= cap - 1) break;
            }
            buf[used] = '\0';
            close(pipefd[0]);
            int status;
            waitpid(pid, &status, 0);
            if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) return -1;
            return 0;
        };
        char arch[128];
        char *argv[] = {
            const_cast<char*>("dpkg"),
            const_cast<char*>("--print-architecture"),
            nullptr
        };
        if (run_capture(argv, arch, sizeof arch) == 0) {
            arch[std::strcspn(arch, "\n")] = '\0';
            return arch;
        } else {
            return "";
        }
    }
public:
    std::string get_self_path() { return _get_self_path(); }
    std::string get_jb_env() { return _get_jb_env(); }
    void init() {
        auto exec = [&](const std::string& cmd) -> std::string {
            std::string result;
            char buf[4096];
            FILE* p = popen(cmd.c_str(), "r");
            if (!p) return result;
            while (fgets(buf, sizeof buf, p)) result += buf;
            pclose(p);
            return result;
        };
        std::string path = exec(std::string("bash -c '" + get_self_path() + "/init.sh --init'"));
        while (!path.empty() && (path.back()=='\n' || path.back()=='\r')) path.pop_back();
        setenv("PATH", std::string(path + ":" + "/bin:/usr/bin:/usr/local/bin:/var/jb/bin:/var/jb/usr/bin:/var/jb/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin:/var/jb/sbin:/var/jb/usr/sbin:/var/jb/usr/local/sbin:/rootfs/usr/bin:/rootfs/bin:/rootfs/sbin:/rootfs/usr/sbin:/rootfs/usr/local/bin:/rootfs/usr/local/sbin").c_str(), 1);
        std::string get_jb_cmd = exec(std::string("bash -c '" + get_self_path() + "/init.sh -gjb'"));
        setenv("jb", get_jb_cmd.c_str(), 1);
        g_jb.jb = get_jb_cmd;
        g_jb.init();
    }
};
} /* namespace a1gui */
inline a1gui::env g_env;
#endif /* A1_ENV_H */
