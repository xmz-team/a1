/*
 * raise_power.cc
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
// build: c++ raise_power.cc -o raise_power && ldid -S../../a1.bin.ens.xml -Hsha1 -Hsha256 -M raise_power && chmod u+s raise_power
/* a simple thing, perform privileged operations to use */

#include <sys/types.h>
#include <libxmz/io.hpp>
#include <libxmz/runsh.hpp>
#include <libxmz/io.hpp>
#include <unistd.h>
#include <stdio.h>
#include <string>
#include <errno.h>

int main(int argc, char* argv[]) {
    uid_t orig_uid = getuid();
    if (argc < 2) {
        xmz::println("Usage:", argv[0], "<command>");
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
