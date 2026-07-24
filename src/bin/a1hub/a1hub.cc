/*
 * a1hub.cc
 * Created by XMZ <ad-ios334@outlook.com> on 2026-07-04
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
// build: c++ a1hub.cc -o a1hub && ldid -S../../../a1.bin.ens.xml -Hsha1 -Hsha256 -M a1hub && chmod u+s a1hub

#include <sys/types.h>
#include <libxmz/io.hpp>
#include <libxmz/runsh.hpp>
#include <unistd.h>
#include <stdio.h>
#include <string>
#include <errno.h>
#include <libxmz/log.hpp>
// #include <libxmz/exec.hpp>

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
