/*
 *  bundle.mm
 *  Added support for Bundle Identifier by XMZ <ad-ios334@outlook.com> on 5/12/25
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
// c++ -fobjc-arc -framework Foundation -framework Security -I. bundle.mm -o bundle && ldid -S../../../a1.bin.ens.xml -Hsha1 -Hsha256 -M  bundle && ln -s bundle bundle_pid && ln -s bundle pid_bundle

#include "bundle_pid.hpp"
#include "pid_bundle.hpp"
#include <libxmz/log.hpp>
#include <string>
#include <cstdlib>

int main(int argc, const char * argv[]) {
    std::string codename = argv[0];
    size_t pos = codename.find_last_of('/');
    if (pos != std::string::npos) {
        codename = codename.substr(pos + 1);
    }

    if (codename == "bundle_pid") {
        if (argc < 2) {
            xmz::print("-1");
            return -1;
        }

        int pid = a1::bin::bundle_pid(argv[1]);
        xmz::print(pid);
        return 0;

    } else if (codename == "pid_bundle") {
        if (argc < 2) {
            xmz::print("-1");
            return -1;
        }

        const char *process_name = a1::bin::pid_bundle(atoi(argv[1]));
        xmz::print(process_name);
        return 0;

    } else {
        if (argc < 2) {
            xmz::perrln("Usage:", argv[0], "<options>");
            xmz::perrln("options:");
            xmz::perrln("  to-pid, tp    <bundle_id>  convert bundle id to pid");
            xmz::perrln("  to-name, tn   <pid>        convert pid to bundle id or process name");
            return 1;
        }

        std::string cmd = argv[1];

        if (cmd == "to-pid" || cmd == "tp") {
            if (argc < 3) {
                xmz::perrln("Missing bundle identifier argument");
                return 1;
            }

            int pid = a1::bin::bundle_pid(argv[2]);  // Use argv[2], not argv[1]
            xmz::print(pid);
            return 0;

        } else if (cmd == "to-name" || cmd == "tn") {
            if (argc < 3) {
                xmz::perrln("Missing PID argument");
                return 1;
            }
            const char *process_name = a1::bin::pid_bundle(atoi(argv[2]));
            xmz::print(process_name);
            return 0;

        } else {
            xmz::log::error("Undefined option:", cmd);
            return 1;
        }
    }
}
