// start.hpp
#pragma once
#include <string>
#include <cstdlib>
#include <sys/wait.h>
#include <unistd.h>

#include <a1/core/ctl/aux.hpp>
#include <a1/core/config.hpp>
#include <a1/core/a1/kill_pid.hpp>
#include <a1/core/program_name.hpp>
#include <src/bin/bundle/bundle.hpp>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>

namespace a1ctl {
    // backstage start up
    inline void start_a1_service() {
        a1::config::jb_path g_jb;
        xmz::log::info("check the configuration...");
        if (check_config_conflict() != 0) {
            xmz::log::error("configuration conflict, startup has stopped");
            return;
        }

        a1::kill_pid();
        sleep(1);

        std::string a1_script;

        if (xmz::aux::is_file((g_jb.jb + "/usr/local/bin/a1"))) a1_script = g_jb.jb + "/usr/local/bin/a1";

        if (a1_script != "") {
            xmz::log::info("pull up A1 service...");
            pid_t pid = fork();
            pid_t pid2 = 0;
            if (pid == 0) {
                pid2 = fork();
                if (pid2 == 0) {
                    int out_fd = open((g_jb.a1_dir + "/a1.log").c_str(), O_WRONLY | O_CREAT | O_APPEND, 0644);
                    if (out_fd >= 0) {
                        dup2(out_fd, STDOUT_FILENO);
                        if (out_fd != STDOUT_FILENO) close(out_fd);
                    }
                    int err_fd = open((g_jb.a1_dir + "/a1error.log").c_str(), O_WRONLY | O_CREAT | O_APPEND, 0644);
                    if (err_fd >= 0) {
                        dup2(err_fd, STDERR_FILENO);
                        if (err_fd != STDERR_FILENO) close(err_fd);
                    }
                    execl((g_jb.jb + "/usr/local/bin/a1").c_str(), a1::config::program_name::a1, nullptr);
                    _exit(127);
                }
                _exit(0);
            } else if (pid > 0) {
                waitpid(pid, nullptr, 0);
            }
            sleep(2);
            if (kill(pid2, 0) == 0) xmz::log::info("A1 has been activated(PID:", pid2, ")");
            else xmz::log::error("A1 startup failed");
        }
    }
    inline int start_a1() {
        a1::config::jb_path g_jb;
        xmz::println("Start A1 optimization...");
        if (check_a1_running() == 0) {
            xmz::println("A1 is already running.");
            xmz::println("use 'a1ctl restart' to restart A1");
            return 1;
        }

        a1::kill_pid();
        sleep(2);
        start_a1_service();
        sleep(1);

        int pid = a1::bin::bundle_pid("cxxa1");
        std::string cxxa1_path = g_jb.a1_dir + "/bin/cxxa1";

        if (pid != -1) {
            xmz::log::info("A1 has been activated(PID:", pid, ")");
            return 1;
        } else {
            xmz::log::error("A1 Startup failed, try the backup startup method...");
            pid_t pid2 = fork();
            if (pid2 == 0) {
                if (std::getenv("jb") != nullptr) {
                    execl(cxxa1_path.c_str(), a1::config::program_name::a1, nullptr);
                } else {
                    setenv("jb", g_jb.jb.c_str(), 1);
                    execl(cxxa1_path.c_str(), a1::config::program_name::a1, nullptr);
                }
            }
            sleep(1);
            if (a1::bin::bundle_pid("cxxa1") != -1) {
                xmz::log::info("A1 has been activated(PID:", pid2, ")");
                return 0;
            } else {
                xmz::log::error("A1 failed to start!");
                return 1;
            }
        }
        return 1;
    }

    inline void start_a1_foreground() {
        a1::config::jb_path g_jb;
        std::string a1_script = g_jb.jb + "/usr/local/bin/a1";
        xmz::log::info("Start A1 optimization (foreground mode)...");
        a1::kill_pid();
        sleep(1);
        xmz::println("_______________________________________________");
        if (xmz::aux::is_file(a1_script)) execl(a1_script.c_str(), a1::config::program_name::a1, nullptr);
        else xmz::log::error("Unable to find A1 script", a1_script);
    }
} /* namespace a1ctl */
