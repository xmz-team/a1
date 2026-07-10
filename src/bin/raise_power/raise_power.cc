/*
 * raise_power.cc
 * Created by XMZ <ad-ios334@outlook.com> on 2026-07-04
 * Copyright (c) 2026 XMZ <ad-ios334@outlook.com> All rights reserved.
 */
// build: c++ raise_power.cc -o raise_power && ldid -S../../a1.bin.ens.xml -Hsha1 -Hsha256 -M raise_power && chmod u+s raise_power
/* 一个简单东西，执行特权操作使用 */

#include <sys/types.h>
#include <libxmz/io.hpp>
#include <libxmz/runsh.hpp>
#include <unistd.h>
#include <stdio.h>
#include <string>
#include <errno.h>

int main(int argc, char* argv[]) {
    uid_t orig_uid = getuid();
    if (argc < 2) {
        printf("Usage: %s <command>\n", argv[0]);
        return 1;
    }

    char* const args[] = {argv[1], nullptr};
    if (setuid(0) != 0) {
        xmz::perrln("setuid(0) failed");
        return 1;
    }
    // xmz::cmd::runsh(command.c_str());
    execvp(argv[1], args);
    if (setuid(orig_uid) != 0) {
        xmz::perrln("Failed to drop privileges");
        return 1;
    }
    return 0;
}
