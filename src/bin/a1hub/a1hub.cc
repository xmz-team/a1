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
#include <libxmz/exec.hpp>

int main(int argc, char* argv[]) {
    if (setuid(0) != 0) {
        xmz::log::error("setuid(0) failed");
        return 1;
    }

    std::string cmd = "a1ctl";
    for (int i = 1; i < argc; i++) {
        cmd += " ";
        cmd += argv[i];
    }

    int ret = xmz::cmd::runbash(cmd.c_str());
    return WEXITSTATUS(ret);
}
