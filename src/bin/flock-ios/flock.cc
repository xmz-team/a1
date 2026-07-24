/*
 * flock.cc
 * Created by XMZ <ad-ios334@outlook.com> on 2026-04-16
 * Copyright (c) 2026 XMZ <xmz-team@outlook.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3.0 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, see
 * <https://www.gnu.org/licenses/lgpl-3.0.html>.
 */
/*
 * build: c++ -o flock flock.cc
 */
/*
 * this is the practice of flock in iphoneos, which is used to replace the problem that iphoneos does not have a flock terminal program
 */

#include <libxmz/io.hpp>
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/wait.h>
#include <unistd.h>
#include <libxmz/aux.hpp>

static volatile sig_atomic_t timeout_expired = 0;
static volatile sig_atomic_t alarm_fired = 0;

static void sigalarm_handler(int sig) {
    (void)sig;
    timeout_expired = 1;
    alarm_fired = 1;
}

// fix: Add a general signal processor for EINTR retry
static void sig_ignore(int sig) {
    (void)sig;
    // it is only used to interrupt flock, not for other processing
}

static void usage(const char *prog) {
    xmz::perrln(
        "Usage:", prog, "[options] <file>|<directory> <command> [<argument>...]\n"
        "      ", prog, "[options] <file>|<directory> -c <command>\n"
        "      ", prog, "[options] <file descriptor number>\n"
        "Manage file locks from shell scripts.\n"
        "Options:\n"
        " -s, --shared     get a shared lock\n"
        " -x, --exclusive  get an exclusive lock (default)\n"
        " -u, --unlock     remove a lock\n"
        " -n, --nonblock   fail rather than wait\n"
        " -w, --wait, --timeout <secs>  wait for a limited amount of time\n"
        " -o, --close      close file descriptor before running command\n"
        " -c, --command <command>  run a single command string through the shell\n"
        " -h, --help       display this help and exit\n"
        " -V, --version    output version information and exit");
    exit(1);
}

static void version(void) {
    xmz::println("flock (darwin compatible) 1.1");
    exit(0);
}

// fix: Package flock system calls and automatically process EINTR retry (except for timeout)
static int flock_with_retry(int fd, int operation, int timeout, int *was_timeout) {
    struct sigaction sa, old_sigalrm, old_sigint, old_sigterm;
    int ret;

    *was_timeout = 0;
    // set up a signal processor so that flock can be interrupted
    sa.sa_handler = sig_ignore;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(SIGINT, &sa, &old_sigint);
    sigaction(SIGTERM, &sa, &old_sigterm);

    if (timeout > 0) {
        sa.sa_handler = sigalarm_handler;
        sigaction(SIGALRM, &sa, &old_sigalrm);
        alarm_fired = 0;
        alarm((unsigned int)timeout);
    }
    // retry cycle: EINTR and retry if the interruption is not caused by timeout
    do {
        ret = flock(fd, operation);
    } while (ret < 0 && errno == EINTR && !alarm_fired);

    if (timeout > 0) {
        alarm(0);
        if (alarm_fired && ret < 0 && errno == EINTR) {
            *was_timeout = 1;
        }

        sigaction(SIGALRM, &old_sigalrm, NULL);
    }

    sigaction(SIGINT, &old_sigint, NULL);
    sigaction(SIGTERM, &old_sigterm, NULL);

    return ret;
}

int main(int argc, char *argv[]) {
    int opt;
    int lock_type = LOCK_EX;
    int nonblock = 0;
    int unlock = 0;
    int close_fd = 0;
    int timeout = -1;
    int use_shell = 0;
    const char *command = NULL;
    const char *filename = NULL;
    int fd;

    static const char *optstring = "+sxunow:c:hV";
    static struct option long_options[] = {
        {"shared",     no_argument, NULL, 's'},
        {"exclusive",  no_argument, NULL, 'x'},
        {"unlock",     no_argument, NULL, 'u'},
        {"nonblock",   no_argument, NULL, 'n'},
        {"close",      no_argument, NULL, 'o'},
        {"wait",       required_argument, NULL, 'w'},
        {"timeout",    required_argument, NULL, 'w'},
        {"command",    required_argument, NULL, 'c'},
        {"help",       no_argument, NULL, 'h'},
        {"version",    no_argument, NULL, 'V'},
        {NULL, 0, NULL, 0}
    };

    while ((opt = getopt_long(argc, argv, optstring, long_options, NULL)) != -1) {
        switch (opt) {
        case 's':
            lock_type = LOCK_SH;
            break;
        case 'x':
            lock_type = LOCK_EX;
            break;
        case 'u':
            unlock = 1;
            break;
        case 'n':
            nonblock = 1;
            break;
        case 'o':
            close_fd = 1;
            break;
        case 'w':
            timeout = atoi(optarg);
            // fix: -w 0 is equivalent to -n
            if (timeout == 0) {
                nonblock = 1;
                timeout = -1;
            } else if (timeout < 0) {
                timeout = -1;
            }
            break;
        case 'c':
            use_shell = 1;
            command = optarg;
            break;
        case 'h':
            usage(argv[0]);
            break;
        case 'V':
            version();
            break;
        default:
            usage(argv[0]);
        }
    }
    // -n is higher than -w
    if (nonblock && timeout > 0) {
        timeout = -1;
    }
    // unlock mode
    if (unlock) {
        if (optind >= argc) usage(argv[0]);
        const char *target = argv[optind];
        char *endptr;
        fd = (int)strtol(target, &endptr, 10);
        if (*endptr == '\0') {
            // pure number, directly used as fd
        } else {
            // fix: Catalog unlocking support
            fd = open(target, O_RDONLY);
            if (fd < 0) {
                fd = open(target, O_RDONLY | O_DIRECTORY);
            }

            if (fd < 0) {
                xmz::perr("open");
                return 1;
            }
        }

        if (flock(fd, LOCK_UN) < 0) {
            xmz::perr("flock");
            return 1;
        }

        if (*endptr != '\0') {
            close(fd);
        }

        return 0;
    }
    // file descriptor mode
    if (optind < argc) {
        const char *arg = argv[optind];
        char *endptr;
        fd = (int)strtol(arg, &endptr, 10);
        if (*endptr == '\0' && optind + 1 == argc) {
            int op = lock_type;
            if (nonblock) op |= LOCK_NB;
            int was_timeout;
            if (flock_with_retry(fd, op, timeout, &was_timeout) < 0) {
                if (was_timeout) {
                    xmz::perrln("flock: timeout waiting for lock");
                } else {
                    xmz::perr("flock");
                }

                return 1;
            }

            return 0;
        }
    }
    // general mode: <file> <command...> or <file> -c <command>
    if (optind >= argc) usage(argv[0]);
    filename = argv[optind++];
    // fix: Intelligent processing of directories and ordinary files
    int open_flags = 0;
    if (lock_type == LOCK_SH) {
        open_flags = O_RDONLY;
    } else {
        open_flags = O_RDWR;
    }
    // try to open it with ordinary files first
    fd = open(filename, open_flags | O_CREAT, 0666);
    // fix: If it fails and it is a directory, try to open it in the directory way
    if (fd < 0 && errno == EISDIR) {
        fd = open(filename, O_RDONLY);
        if (fd >= 0) {
            // dir can be used to obtain exclusive locks in read-only mode (Linux behavior)
            // flock doesn't care about read and write rights, only cares about the lock type
        }
    }
    // repair: macOS needs O_DIRECTORY to open some directories
    if (fd < 0 && errno == EISDIR) {
        fd = open(filename, O_RDONLY | O_DIRECTORY);
    }

    if (fd < 0) {
        xmz::perr("open");
        return 1;
    }

    // check whether there is a command to run
    if (use_shell && command) {
        // -c has specified the command
    } else if (optind >= argc) {
        xmz::perrln("flock: missing command");
        usage(argv[0]);
    }
    // run flock
    int op = lock_type;
    if (nonblock) op |= LOCK_NB;

    int was_timeout = 0;
    if (flock_with_retry(fd, op, timeout, &was_timeout) < 0) {
        if (was_timeout) {
            xmz::perrln("flock: timeout waiting for lock");
        } else {
            xmz::perr("flock");
        }

        close(fd);
        return 1;
    }
    // fix: Set FD_CLOEXEC before fork to prevent accidental inheritance of sub-process
    if (!close_fd) {
        fcntl(fd, F_SETFD, FD_CLOEXEC);
    }
    // run command
    pid_t pid = fork();
    if (pid < 0) {
        xmz::perr("fork");
        close(fd);
        return 1;
    }

    if (pid == 0) {
        // sub-process
        if (close_fd) {
            close(fd);
        }

        if (use_shell) {
            if (xmz::aux::is_file("/bin/sh") == 0) {
                execl("/bin/sh", "sh", "-c", command, (char *)NULL);
            } else if (xmz::aux::is_file("/usr/bin/sh") == 0) {
                execl("/usr/bin/sh", "sh", "-c", command, (char *)NULL);
            } else if (xmz::aux::is_file("/usr/local/bin/sh") == 0) {
                execl("/usr/local/bin/sh", "sh", "-c", command, (char *)NULL);
            } else if (xmz::aux::is_file("/var/jb/bin/sh") == 0) {
                execl("/var/jb/bin/sh", "sh", "-c", command, (char *)NULL);
            } else if (xmz::aux::is_file("/var/jb/usr/bin/sh") == 0) {
                execl("/var/jb/usr/bin/sh", "sh", "-c", command, (char *)NULL);
            } else if (xmz::aux::is_file("/var/jb/usr/local/bin/sh") == 0) {
                execl("/var/jb/usr/local/bin/sh", "sh", "-c", command, (char *)NULL);
            }
        } else {
            execvp(argv[optind], &argv[optind]);
        }

        xmz::perr("exec");
        _exit(1);
    }
    // the parent process waits for the child process
    int status;
    while (waitpid(pid, &status, 0) < 0) {
        if (errno != EINTR) {
            xmz::perr("waitpid");
            close(fd);
            return 1;
        }
    }

    close(fd);

    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
        return 128 + WTERMSIG(status);
    }

    return 1;
}
