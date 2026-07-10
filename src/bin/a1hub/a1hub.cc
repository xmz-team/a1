/*
 * a1hub.cc
 * Created by XMZ <ad-ios334@outlook.com> on 2026-07-04
 * Copyright (c) 2026 XMZ <ad-ios334@outlook.com> All rights reserved.
 */
// build: c++ a1hub.cc -o a1hub && ldid -S../../../a1.bin.ens.xml -Hsha1 -Hsha256 -M a1hub && chmod u+s a1hub

#include <sys/types.h>
#include <libxmz/io.hpp>
#include <libxmz/runsh.hpp>
#include <unistd.h>
#include <stdio.h>
#include <string>
#include <errno.h>
#include <libxmz/log.hpp>

int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("Usage: %s <command> [args...]\n", argv[0]);
        return 1;
    }
    // 提升到 root 权限
    if (setuid(0) != 0) {
        xmz::log::error("setuid(0) failed");
        return 1;
    }
    // 构造参数数组: a1ctl + 所有传入的参数
    char* args[argc + 1];
    args[0] = (char*)"a1ctl";
    for (int i = 1; i < argc; i++) {
        args[i] = argv[i];
    }
    args[argc] = nullptr;
    // 执行 a1ctl，成功则不返回
    execvp("a1ctl", args);
    // 只有 execvp 失败才会执行到这里
    xmz::log::error("execvp failed");
    return 1;
}
