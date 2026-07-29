/*
 * flock.hpp
 * Created by XMZ <ad-ios334@outlook.com> on 2026-07-28
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

#pragma once
#include <libxmz/io.hpp>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/wait.h>
#include <unistd.h>

inline volatile sig_atomic_t timeout_expired = 0;
inline volatile sig_atomic_t alarm_fired = 0;

inline void sigalarm_handler(int sig) {
    (void)sig;
    timeout_expired = 1;
    alarm_fired = 1;
}

// fix: Add a general signal processor for EINTR retry
inline void sig_ignore(int sig) {
    (void)sig;
    // it is only used to interrupt flock, not for other processing
}

// fix: Package flock system calls and automatically process EINTR retry (except for timeout)
inline int flock_with_retry(int fd, int operation, int timeout, int *was_timeout) {
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
