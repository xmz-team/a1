#!/bin/bash
set -exuo pipefail

if [[ "$(dpkg --print-architecture)" == "iphoneos-arm64" ]]; then
    jb="/var/jb"
else
    unset jb
    if [[ "$(dpkg --print-architecture)" == "iphoneos-arm64e" ]]; then
        jb="$(jbroot)"
    else
        unset jb
        jb=""
    fi
fi

origpwd="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"

init()
{
    date_dir="$($date "+%Y%m%d-%H%M%S")"
    cd packages
    $mkdir -p packdeb.d/a1/$date_dir/
    $mkdir -p packdeb.d/gui/$date_dir/
    
    cd a1
    for f in *.deb; do
        [ -f "$f" ] && $mv "$f" ../packdeb.d/a1/$date_dir/
    done

    cd ../gui
    for f in *.deb; do
        [ -f "$f" ] && $mv "$f" ../packdeb.d/gui/$date_dir/
    done

    cd ..
    $rm -rf a1 gui
    $cp -a a1.template.d a1
    $cp -a gui.template.d gui
}

orig_pwd="$origpwd"

package()
{
		local src_a1="src/a1"
		local src_bin="src/bin"
		local src_gui="src/gui"
		local rl_pack_a1="packages/a1/rootless"
		local rh_pack_a1="packages/a1/roothide"
		local rf_pack_a1="packages/a1/rootful"
		local rl_pack_gui="packages/gui/rootless"
		local rh_pack_gui="packages/gui/roothide"
      SCRIPT_DIR="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"
      source "${SCRIPT_DIR}/../version.ini"

		local a1_deb_d="src/DEBIANS/DEBIAN.a1"
		local gui_deb_d="src/DEBIANS/DEBIAN.gui"

		mv_a1_rl_deb_d()
		{
				$cp -a $a1_deb_d $rl_pack_a1/
				cd $rl_pack_a1 && mv DEBIAN.a1 DEBIAN
				cd DEBIAN
				export arch='iphoneos-arm64'
				export version="$a1_version"
				$envsubst < control.a1 > control
				$rm control.a1
				unset arch version
				cd $orig_pwd
		}
		mv_a1_rh_deb_d()
		{
				$cp -a $a1_deb_d $rh_pack_a1/
				cd $rh_pack_a1 && mv DEBIAN.a1 DEBIAN
				cd DEBIAN
				export arch='iphoneos-arm64e'
				export version="$a1_version"
				$envsubst < control.a1 > control
				$rm control.a1
				unset arch version
				cd $orig_pwd
		}
		mv_a1_rf_deb_d()
		{
				$cp -a $a1_deb_d $rf_pack_a1/
				cd $rf_pack_a1 && mv DEBIAN.a1 DEBIAN
				cd DEBIAN
				export arch='iphoneos-arm'
				export version="$a1_version"
				$envsubst < control.a1 > control
				$rm control.a1
				unset arch version
				cd $orig_pwd
		}
		mv_gui_rl_deb_d()
		{
				$cp -a $gui_deb_d $rl_pack_gui/
				cd $rl_pack_gui && mv DEBIAN.gui DEBIAN && cd DEBIAN
				export version="$gui_version"
				export arch='iphoneos-arm64'
				$envsubst < control.gui > control
				$rm control.gui
				unset version arch
				cd $orig_pwd
		}

		mv_gui_rh_deb_d()
		{
				$cp -a $gui_deb_d $rh_pack_gui/
				cd $rh_pack_gui && mv DEBIAN.gui DEBIAN && cd DEBIAN
				export version="$gui_version"
				export arch='iphoneos-arm64e'
				$envsubst < control.gui > control
				$rm control.gui
				unset version arch
				cd $orig_pwd
		}
		mv_a1_rl_deb_d
		mv_a1_rh_deb_d
		mv_a1_rf_deb_d
		mv_gui_rl_deb_d
      mv_gui_rh_deb_d

		cd packages/a1
		$dpkg_deb -b rootless a1_rl.deb && $dpkg_name a1_rl.deb
		$dpkg_deb -b roothide a1_rh.deb && $dpkg_name a1_rh.deb
		$dpkg_deb -b rootful a1_rf.deb && $dpkg_name a1_rf.deb
		cd ../gui
		$dpkg_deb -b rootless gui_rl.deb && $dpkg_name gui_rl.deb
		$dpkg_deb -b roothide gui_rh.deb && $dpkg_name gui_rh.deb

      cd $orig_pwd
      # cd packages
}

main() { init; package; }
main

