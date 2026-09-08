# pm_core.sh
# Provides all the core features of A1PM

_A1PmCoreFilePath=$( cd $(dirname ${BASH_SOURCE[0]} ) && pwd )
source "$_A1PmCoreFilePath/core_mod.sh"

# 从URL中生成, 因为直接指定容易冲突
_a1pm_url_to_repo_name() {
    local url="$1"
    echo "$url" | sed 's|^https\?://||' | sed 's|/$||' | tr '/' '_'
}

_a1pm_init_repo_list() {
    if [ ! -f "$REPO_LIST" ]; then
        cat > "$REPO_LIST" << 'EOF'
{
  "repositories": {},
  "last_update": ""
}
EOF
    fi
}

_a1pm_add_repo() {
    local url="$1"
    if [ -z "$url" ]; then
        ilog "Usage: add-repo <url>"
        return 1
    fi
    # 标准化 URL
    url="${url%/}"
    # 从URL自动生成名称
    local name=$(_a1pm_url_to_repo_name "$url")
    _a1pm_init_repo_list
    # 备份当前 repos.json
    local repos_backup="${REPO_LIST}.backup"
    $CP "$REPO_LIST" "$repos_backup"
    # 检查是否已存在
    if $JQ -e ".repositories[\"$name\"]" "$REPO_LIST" >/dev/null 2>&1; then
        wlog "仓库 '$name' 已存在，将更新 URL"
    fi
    local repo_entry=$($JQ -n \
        --arg name "$name" \
        --arg url "$url" \
        --arg date "$($DATE '+%Y-%m-%d %H:%M:%S')" \
        '{
            "url": $url,
            "maintainer": "",
            "description": "",
            "display_name": "",
            "added_date": $date,
            "enabled": true,
            "last_sync": ""
        }')
    $JQ --arg name "$name" --argjson entry "$repo_entry" \
        '.repositories[$name] = $entry' \
        "$REPO_LIST" > "${REPO_LIST}.tmp"
    if [ $? -eq 0 ]; then
        $MV "${REPO_LIST}.tmp" "$REPO_LIST"
        ilog "仓库已添加: $name"
        echo "  URL: $url"
        if ! sync_repo_metadata "$name"; then
            wlog "仓库同步失败，正在回滚添加操作..."
            if [ -f "$repos_backup" ]; then
                $MV "$repos_backup" "$REPO_LIST"
                ilog "已回滚操作"
            fi
            $RM -f "$CACHE_DIR/repos/${name}_Packages.json"
            return 1
        fi
        $RM -f "$repos_backup"
    else
        elog "添加仓库失败"
        if [ -f "$repos_backup" ]; then
            $MV "$repos_backup" "$REPO_LIST"
            ilog "已回滚"
        fi
        return 1
    fi
}
# 删除仓库
_a1pm_remove_repo() {
    local name="$1"
    if [ -z "$name" ]; then
        elog "remove_repo <name>"
        return 1
    fi
    if ! $JQ -e ".repositories[\"$name\"]" "$REPO_LIST" >/dev/null 2>&1; then
        elog "仓库不存在: $name"
        return 1
    fi
    $JQ "del(.repositories[\"$name\"])" "$REPO_LIST" > "${REPO_LIST}.tmp"
    $MV "${REPO_LIST}.tmp" "$REPO_LIST"
    # 清理缓存的包索引
    $RM -f "$CACHE_DIR/repos/${name}_Packages.json"
    ilog "仓库已删除: $name"
}
# 列出仓库
_a1pm_list_repos() {
    _a1pm_init_repo_list
    ilog "已配置的远端仓库"
    local repos=$($JQ -r '.repositories | keys[]' "$REPO_LIST" 2>/dev/null)
    if [ -z "$repos" ]; then
        ilog "  暂无配置仓库"
        return
    fi
    for repo in $repos; do
        local url=$($JQ -r ".repositories[\"$repo\"].url" "$REPO_LIST")
        local maintainer=$($JQ -r ".repositories[\"$repo\"].maintainer" "$REPO_LIST")
        local desc=$($JQ -r ".repositories[\"$repo\"].description" "$REPO_LIST")
        local enabled=$($JQ -r ".repositories[\"$repo\"].enabled" "$REPO_LIST")
        local last_sync=$($JQ -r ".repositories[\"$repo\"].last_sync" "$REPO_LIST")
        local status=$([ "$enabled" = "true" ] && echo "✓ 启用" || echo "✗ 禁用")
        echo ""
        echo "  $repo ($status)"
        echo "    URL: $url"
        echo "    维护者: $maintainer"
        [ -n "$desc" ] && echo "    描述: $desc"
        [ "$last_sync" != "" ] && echo "    最后同步: $last_sync"
    done
}
# 同步仓库元数据
_a1pm_sync_repo_metadata() {
    local repo_name="$1"
    if [ -z "$repo_name" ]; then
        # 同步所有仓库
        _a1pm_init_repo_list
        local repos=$($JQ -r '.repositories | keys[]' "$REPO_LIST" 2>/dev/null)
        for repo in $repos; do
            _a1pm_sync_repo_metadata "$repo"
        done
        return
    fi
    # 保存当前状态用于回滚
    local repo_backup="$CACHE_DIR/repos/${repo_name}.repo.backup"
    local pkg_backup="$CACHE_DIR/repos/${repo_name}_Packages.backup"
    local repo_meta_file="$CACHE_DIR/repos/${repo_name}.repo.json"
    local pkg_index_file="$CACHE_DIR/repos/${repo_name}_Packages.json"
    # 备份当前文件
    [ -f "$repo_meta_file" ] && $CP "$repo_meta_file" "$repo_backup"
    [ -f "$pkg_index_file" ] && $CP "$pkg_index_file" "$pkg_backup"
    # 备份 repos.json
    local repos_backup="${REPO_LIST}.backup"
    $CP "$REPO_LIST" "$repos_backup"
    local repo_url=$($JQ -r ".repositories[\"$repo_name\"].url" "$REPO_LIST" 2>/dev/null)
    if [ -z "$repo_url" ] || [ "$repo_url" = "null" ]; then
        elog "仓库不存在: $repo_name"
        return 1
    fi
    ilog "同步仓库元数据: $repo_name"
    # 创建缓存目录
    $MKDIR -p "$CACHE_DIR/repos"
    # 下载 .repo.json
    local repo_meta_url="${repo_url}/.repo.json"
    ilog "下载仓库元数据: $repo_meta_url"
    if curl -sL --connect-timeout 10 --max-time 30 "$repo_meta_url" -o "$repo_meta_file" 2>/dev/null; then
        if $JQ empty "$repo_meta_file" 2>/dev/null; then
            # 从 .repo.json 读取维护者信息并更新到 repos.json
            local remote_maintainer=$($JQ -r '.maintainer // ""' "$repo_meta_file")
            local remote_description=$($JQ -r '.description // ""' "$repo_meta_file")
            local remote_name=$($JQ -r '.name // ""' "$repo_meta_file")
            # 更新 repos.json 中的维护者、描述、名称信息
            $JQ --arg name "$repo_name" \
                --arg maintainer "$remote_maintainer" \
                --arg description "$remote_description" \
                --arg display_name "$remote_name" \
                '.repositories[$name].maintainer = $maintainer |
                 .repositories[$name].description = if $description != "" then $description else .repositories[$name].description end |
                 .repositories[$name].display_name = $display_name' \
                "$REPO_LIST" > "${REPO_LIST}.tmp"
            $MV "${REPO_LIST}.tmp" "$REPO_LIST"
            # 检查 modules 字段类型
            local modules_type=$(jq -r '.modules | type' "$repo_meta_file" 2>/dev/null)
            local pkg_url=""
            if [ "$modules_type" = "string" ]; then
                pkg_url=$($JQ -r '.modules' "$repo_meta_file")
                ilog "检测到字符串格式的 modules 字段: $pkg_url"
            elif [ "$modules_type" = "object" ]; then
                pkg_url=$($JQ -r '.modules.packages // "Packages.json"' "$repo_meta_file")
            elif [ "$modules_type" = "null" ] || [ -z "$modules_type" ]; then
                pkg_url="Packages.json"
                wlog "未找到 modules 字段，使用默认值: $pkg_url"
            else
                pkg_url="Packages.json"
                wlog "  未知的 modules 字段类型: $modules_type，使用默认值: $pkg_url"
            fi
            # 构建包索引 URL
            local pkg_index_url="${repo_url}/${pkg_url}"
            ilog "下载包索引: $pkg_index_url"
            if curl -sL --connect-timeout 10 --max-time 60 "$pkg_index_url" -o "$pkg_index_file" 2>/dev/null; then
                if $JQ empty "$pkg_index_file" 2>/dev/null; then
                    # 更新同步时间
                    local current_date=$($DATE '+%Y-%m-%d %H:%M:%S')
                    $JQ --arg name "$repo_name" --arg date "$current_date" \
                        ".repositories[\"$name\"].last_sync = \$date" \
                        "$REPO_LIST" > "${REPO_LIST}.tmp"
                    $MV "${REPO_LIST}.tmp" "$REPO_LIST"
                    local pkg_count=$($JQ 'length' "$pkg_index_file" 2>/dev/null || echo 0)
                    ilog "仓库同步完成: $pkg_count 个包"
                    # 清理备份
                    $RM -f "$repo_backup" "$pkg_backup" "$repos_backup"
                    return 0
                else
                    elog "包索引格式无效"
                    rollback_sync "$repo_name" "$repo_backup" "$pkg_backup" "$repos_backup"
                    return 1
                fi
            else
                wlog "无法下载包索引: $pkg_index_url"
                rollback_sync "$repo_name" "$repo_backup" "$pkg_backup" "$repos_backup"
                return 1
            fi
        else
            elog "仓库元数据格式无效"
            rollback_sync "$repo_name" "$repo_backup" "$pkg_backup" "$repos_backup"
            return 1
        fi
    else
        elog "目标: ${repo_url} 没有 .repo.json!"
        elog "这可能是一个无效的repo"
    fi
}

# rollback
_a1pm_rollback_sync() {
    local repo_name="$1"
    local repo_backup="$2"
    local pkg_backup="$3"
    local repos_backup="$4"
    wlog "同步失败，正在回滚..."
    # 恢复 repos.json
    if [ -f "$repos_backup" ]; then
        $MV "$repos_backup" "$REPO_LIST"
        ilog "已恢复仓库列表"
    fi
    # 恢复仓库元数据
    if [ -f "$repo_backup" ]; then
        $MV "$repo_backup" "$CACHE_DIR/repos/${repo_name}.repo.json"
        ilog "已恢复仓库元数据"
    else
        $RM -f "$CACHE_DIR/repos/${repo_name}.repo.json"
    fi
    # 恢复包索引
    if [ -f "$pkg_backup" ]; then
        $MV "$pkg_backup" "$CACHE_DIR/repos/${repo_name}_Packages.json"
        ilog "已恢复包索引"
    else
        $RM -f "$CACHE_DIR/repos/${repo_name}_Packages.json"
    fi
    # 清理临时文件
    $RM -f "${REPO_LIST}.tmp"
    ilog "已回滚到同步前的状态"
}
# 搜索远端包
_a1pm_search_remote() {
    local query="$1"
    local found=false
    _a1pm_init_repo_list
    $MKDIR -p "$CACHE_DIR/repos"
    ilog "搜索远端包: '$query'"
    echo ""
    local repos=$($JQ -r '.repositories | keys[]' "$REPO_LIST" 2>/dev/null)
    for repo in $repos; do
        local pkg_file="$CACHE_DIR/repos/${repo}_Packages.json"
        if [ ! -f "$pkg_file" ]; then
            continue
        fi
        local results=$($JQ -c --arg q "$query" \
            '.[] | select(
                .package | test($q; "i")
            )' "$pkg_file" 2>/dev/null)
        if [ -n "$results" ]; then
            echo "仓库: $repo"
            echo "$results" | while IFS= read -r pkg; do
                local package=$(echo "$pkg" | $JQ -r '.package')
                local name=$(echo "$pkg" | $JQ -r '.name')
                local version=$(echo "$pkg" | $JQ -r '.version')
                local author=$(echo "$pkg" | $JQ -r '.author')
                local desc=$(echo "$pkg" | $JQ -r '.description[0] // "无描述"')
                local size=$(echo "$pkg" | $JQ -r '.size // 0')
                local size_hr=$(numfmt --to=iec $size 2>/dev/null || echo "${size}B")
                # 检查是否已安装
                local installed=$($JQ -r \
                    ".modules.official[\"$package\"] // .modules.user[\"$package\"] // empty" \
                    "$MODULE_DB" 2>/dev/null)
                local status=""
                if [ -n "$installed" ]; then
                    local installed_ver=$(echo "$installed" | $JQ -r '.version')
                    if [ "$installed_ver" = "$version" ]; then
                        status="[已安装]"
                    else
                        status="[已安装 $installed_ver, 可用 $version]"
                    fi
                fi
                echo ""
                echo "  $package ($name) v$version $status"
                echo "    作者: $author"
                echo "    大小: $size_hr"
                echo "    描述: $desc"
            done
            found=true
        fi
    done
    if [ "$found" = false ]; then
        wlog "  未找到匹配的包"
        ilog "  提示: 使用 'sync' 命令更新包索引"
    fi
}
# 列出远端可用包
_a1pm_list_remote() {
    local repo_filter="$1"
    _a1pm_init_repo_list
    $MKDIR -p "$CACHE_DIR/repos"
    ilog "远端可用包"
    local repos
    if [ -n "$repo_filter" ]; then
        repos="$repo_filter"
    else
        repos=$($JQ -r '.repositories | keys[]' "$REPO_LIST" 2>/dev/null)
    fi
    for repo in $repos; do
        local pkg_file="$CACHE_DIR/repos/${repo}_Packages.json"
        if [ ! -f "$pkg_file" ]; then
            wlog "  仓库 $repo 未同步，请运行: sync"
            continue
        fi
        echo ""
        echo "$repo"
        local packages=$($JQ -r '.[] | "\(.package)\t\(.name)\t\(.version)\t\(.author)"' "$pkg_file" 2>/dev/null)
        if [ -z "$packages" ]; then
            wlog "  暂无包"
            continue
        fi
        echo "$packages" | while IFS=$'\t' read -r package name version author; do
            local installed=$($JQ -r \
                ".modules.official[\"$package\"] // .modules.user[\"$package\"] // empty" \
                "$MODULE_DB" 2>/dev/null)
            local status=""
            if [ -n "$installed" ]; then
                local installed_ver=$(echo "$installed" | $JQ -r '.version')
                if [ "$installed_ver" = "$version" ]; then
                    status="[已安装]"
                else
                    status="[更新可用]"
                fi
            fi
            printf "  %-30s %-20s v%-10s %-15s %s\n" \
                "$package" "$name" "$version" "$author" "$status"
        done
    done
}
# 显示包详情
_a1pm_show_remote_info() {
    local package="$1"
    if [ -z "$package" ]; then
        elog "用法: info <package>"
        return 1
    fi
    init_repo_list
    $MKDIR -p "$CACHE_DIR/repos"
    local repos=$($JQ -r '.repositories | keys[]' "$REPO_LIST" 2>/dev/null)
    local found=false
    for repo in $repos; do
        local pkg_file="$CACHE_DIR/repos/${repo}_Packages.json"
        if [ ! -f "$pkg_file" ]; then
            continue
        fi
        local pkg_info=$($JQ -c --arg pkg "$package" \
            '.[] | select(.package == $pkg)' "$pkg_file" 2>/dev/null)
        if [ -n "$pkg_info" ]; then
            echo "包信息: $package"
            echo "仓库: $repo"
            echo ""
            local name=$(echo "$pkg_info" | $JQ -r '.name')
            local version=$(echo "$pkg_info" | $JQ -r '.version')
            local author=$(echo "$pkg_info" | $JQ -r '.author')
            local maintainer=$(echo "$pkg_info" | $JQ -r '.maintainer')
            local size=$(echo "$pkg_info" | $JQ -r '.size // 0')
            local filename=$(echo "$pkg_info" | $JQ -r '.filename')
            local sha256=$(echo "$pkg_info" | $JQ -r '.sha256 // "无"')
            local section=$(echo "$pkg_info" | $JQ -r '.section // "无"')
            local priority=$(echo "$pkg_info" | $JQ -r '.priority // "optional"')
            local homepage=$(echo "$pkg_info" | $JQ -r '.homepage // ""')
            echo "名称: $name"
            echo "版本: $version"
            echo "作者: $author"
            echo "维护者: $maintainer"
            echo "大小: $(numfmt --to=iec $size 2>/dev/null || echo "${size}B")"
            echo "SHA256: $sha256"
            echo "分类: $section"
            echo "优先级: $priority"
            [ -n "$homepage" ] && echo "主页: $homepage"
            echo ""
            echo "描述:"
            echo "$pkg_info" | $JQ -r '.description[] | "  \(.)"' 2>/dev/null
            echo ""
            local deps=$(echo "$pkg_info" | $JQ -r '.depends[]?' 2>/dev/null)
            if [ -n "$deps" ]; then
                echo "模块依赖:"
                echo "$deps" | while IFS= read -r dep; do
                    echo "  - $dep"
                done
            fi
            local apt_deps=$(echo "$pkg_info" | $JQ -r '.depends_apt[]?' 2>/dev/null)
            if [ -n "$apt_deps" ]; then
                echo "系统依赖:"
                echo "$apt_deps" | while IFS= read -r dep; do
                    echo "  - $dep"
                done
            fi
            echo ""
            local update_log=$(echo "$pkg_info" | $JQ -r '.update_log[]?' 2>/dev/null)
            if [ -n "$update_log" ]; then
                echo "更新日志:"
                echo "$update_log" | while IFS= read -r log; do
                    echo "  - $log"
                done
            fi
            found=true
            break
        fi
    done
    if [ "$found" = false ]; then
        wlog "未找到包: $package"
        ilog "提示: 使用 'sync' 更新索引，或 'search' 搜索包"
        return 1
    fi
}
# 从远端安装
_a1pm_install_remote() {
    local package="$1"
    if [ -z "$package" ]; then
        elog "用法: install_remote <package>"
        return 1
    fi
    _a1pm_init_repo_list
    # 查找包在哪个仓库
    local repos=$($JQ -r '.repositories | keys[]' "$REPO_LIST" 2>/dev/null)
    local found_repo=""
    local pkg_info=""
    for repo in $repos; do
        local pkg_file="$CACHE_DIR/repos/${repo}_Packages.json"
        if [ ! -f "$pkg_file" ]; then
            wlog "仓库 $repo 未同步，正在同步..."
            sync_repo_metadata "$repo"
        fi
        pkg_info=$($JQ -c --arg pkg "$package" \
            '.[] | select(.package == $pkg)' "$pkg_file" 2>/dev/null)
        if [ -n "$pkg_info" ]; then
            found_repo="$repo"
            break
        fi
    done
    if [ -z "$found_repo" ]; then
        elog "未找到包: $package"
        ilog "提示: 使用 'search' 搜索包"
        return 1
    fi
    local repo_url=$($JQ -r ".repositories[\"$found_repo\"].url" "$REPO_LIST")
    local file_path=$(echo "$pkg_info" | $JQ -r '.FilePath // ""')
		local filename=$(echo "pkg_info" | $JQ -r '.filename')
    # 构建下载路径
    local download_path=""
    if [ -n "$file_path" ] && [ "$file_path" != "null" ] && [ "$file_path" != "" ]; then
        download_path="$file_path"
    fi
    # 构建完整的下载 URL
    local download_url="${repo_url}/${download_path}"
    download_url=$(echo "$download_url" | sed 's#//+#/#g' | sed "s#${repo_url}/#${repo_url}/#")
    # 本地缓存路径
    local cache_filename=$(basename "$download_path")
    local download_cache="$CACHE_DIR/downloads/$cache_filename"
    local sha256_expected=$(echo "$pkg_info" | $JQ -r '.sha256 // ""')
    $MKDIR -p "$CACHE_DIR/downloads"
    ilog "从仓库 '$found_repo' 下载: $package"
    echo "  URL: $download_url"
    echo "  路径: $download_path"
    # 下载包
    if curl -L --progress-bar --connect-timeout 10 --max-time 300 \
        "$download_url" -o "$download_cache" 2>/dev/null; then
        local file_size=$(stat -f%z "$download_cache" 2>/dev/null || stat -c%s "$download_cache" 2>/dev/null)
        ilog "下载完成 (${file_size} 字节)"
        # 验证 SHA256
        if [ -n "$sha256_expected" ] && [ "$sha256_expected" != "null" ]; then
            ilog "验证文件完整性..."
            if command -v shasum &>/dev/null; then
                local sha256_actual=$(shasum -a 256 "$download_cache" | cut -d' ' -f1)
                if [ "$sha256_actual" != "$sha256_expected" ]; then
                    elog "SHA256 验证失败！"
                    echo "  期望: $sha256_expected"
                    echo "  实际: $sha256_actual"
                    $RM -f "$download_cache"
                    return 1
                fi
                ilog "文件完整性验证通过"
            else
                wlog "shasum 未安装，跳过验证"
            fi
        fi
        # 安装下载的包
        _a1mod_install_module "$download_cache"
        local install_result=$?
        # 清理下载文件
        $RM -f "$download_cache"
        return $install_result
    else
        elog "下载失败"
        ilog "尝试的 URL: $download_url"
        $RM -f "$download_cache"
        return 1
    fi
}
# 检查更新
_a1pm_check_updates() {
    ilog "检查远端更新..."
    # 先同步索引
    local repos=$($JQ -r '.repositories | keys[]' "$REPO_LIST" 2>/dev/null)
    for repo in $repos; do
        _a1pm_sync_repo_metadata "$repo" &
    done
    wait
    echo ""
    echo "可用更新"
    local has_updates=false
    # 检查已安装的模块
    local installed_packages=$($JQ -r \
        '.modules.official | keys[], .modules.user | keys[]' \
        "$MODULE_DB" 2>/dev/null)
    for package in $installed_packages; do
        local installed_ver=$($JQ -r \
            ".modules.official[\"$package\"].version // .modules.user[\"$package\"].version" \
            "$MODULE_DB")
        # 在所有仓库中查找
        for repo in $repos; do
            local pkg_file="$CACHE_DIR/repos/${repo}_Packages.json"
            [ ! -f "$pkg_file" ] && continue
            local remote_ver=$($JQ -r --arg pkg "$package" \
                '.[] | select(.package == $pkg) | .version' \
                "$pkg_file" 2>/dev/null)
            if [ -n "$remote_ver" ] && [ "$remote_ver" != "$installed_ver" ]; then
                echo "  $package: $installed_ver → $remote_ver (仓库: $repo)"
                has_updates=true
            fi
        done
    done
    if [ "$has_updates" = false ]; then
        ilog "所有模块已是最新版本"
    fi
}
# 升级所有模块
_a1pm_upgrade_modules() {
    local specific_package="$1"
    ilog "升级模块..."
    _a1pm_sync_repo_metadata
    local repos=$($JQ -r '.repositories | keys[]' "$REPO_LIST" 2>/dev/null)
    local upgraded=false
    if [ -n "$specific_package" ]; then
        # 升级特定包
        local package="$specific_package"
        local installed_ver=$($JQ -r \
            ".modules.official[\"$package\"].version // .modules.user[\"$package\"].version" \
            "$MODULE_DB" 2>/dev/null)
        if [ -z "$installed_ver" ]; then
            elog "模块未安装: $package"
            return 1
        fi
        for repo in $repos; do
            local pkg_file="$CACHE_DIR/repos/${repo}_Packages.json"
            [ ! -f "$pkg_file" ] && continue
            local remote_ver=$($JQ -r --arg pkg "$package" \
                '.[] | select(.package == $pkg) | .version' \
                "$pkg_file" 2>/dev/null)
            if [ -n "$remote_ver" ] && [ "$remote_ver" != "$installed_ver" ]; then
                echo "  升级: $package $installed_ver → $remote_ver"
                remove_module "$package" 2>/dev/null
                install_remote "$package"
                upgraded=true
            fi
        done
    else
        # 升级所有
        local installed_packages=$($JQ -r \
            '.modules.official | keys[], .modules.user | keys[]' \
            "$MODULE_DB" 2>/dev/null)
        for package in $installed_packages; do
            local installed_ver=$($JQ -r \
                ".modules.official[\"$package\"].version // .modules.user[\"$package\"].version" \
                "$MODULE_DB")
            for repo in $repos; do
                local pkg_file="$CACHE_DIR/repos/${repo}_Packages.json"
                [ ! -f "$pkg_file" ] && continue
                local remote_ver=$($JQ -r --arg pkg "$package" \
                    '.[] | select(.package == $pkg) | .version' \
                    "$pkg_file" 2>/dev/null)
                if [ -n "$remote_ver" ] && [ "$remote_ver" != "$installed_ver" ]; then
                    echo "  升级: $package $installed_ver → $remote_ver"
                    _a1mod_remove_module "$package" 2>/dev/null
                    _a1mod_install_remote "$package"
                    upgraded=true
                fi
            done
        done
    fi
    if [ "$upgraded" = false ]; then
        ilog "所有模块已是最新版本"
    fi
}

# api {
# 公共api
init_repo_list() { _a1pm_init_repo_list; }
add_repo() { _a1pm_add_repo "$@"; }
remove_repo() { _a1pm_remove_repo "$@"; }
list_repos() { _a1pm_list_repos; }
sync_repo_metadata() { _a1pm_sync_repo_metadata "$@"; }
rollback_sync() { _a1pm_rollback_sync "$@"; }
search_remote() { _a1pm_search_remote "$@"; }
list_remote() { _a1pm_list_remote "$@"; }
show_remote_info() { _a1pm_show_remote_info "$@"; }
install_remote() { _a1pm_install_remote "$@"; }
check_updates() { _a1pm_check_updates "$@"; }
upgrade_modules() { _a1pm_upgrade_modules "$@"; }
# }
# 导出api
export -f _a1pm_init_repo_list
export -f _a1pm_add_repo
export -f _a1pm_remove_repo
export -f _a1pm_list_repos
export -f _a1pm_sync_repo_metadata
export -f _a1pm_rollback_sync
export -f _a1pm_search_remote
export -f _a1pm_list_remote
export -f _a1pm_show_remote_info
export -f _a1pm_install_remote
export -f _a1pm_check_updates
export -f _a1pm_upgrade_modules
