// cxxa1pm.cc

#include <string>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>

#include <a1/core/pm/a1pmcore.hpp>

std::string help_text(const std::string& myself) {
    return std::string(R"(Usage: )" + myself + " <command> [options]" + R"(
command:
  add-repo <url>			添加远端仓库
  remove-repo <url>			删除远端仓库
  list-repo					列出所有仓库
  update					同步仓库索引
  search <package id>		搜索远端包
  list [repo url]			列出远端可用包
  info <package id>			显示远端包详细信息
  install <package id>		从远端安装包
  upgrade [package id]		升级模块
  upgrade-full				升级全部模块
  check-update				检查可用更新
  help						显示此帮助信息
  version					显示版本号
)";
}


