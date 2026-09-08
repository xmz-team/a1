# check_a1mod.sh
# A1MOD’s check api
_a1mod_check_required() {
    local metadata="$1"
    local required_fields=("package" "mainstream" "version" "description" "target")
    for field in "${required_fields[@]}"; do
        if ! echo "$metadata" | $JQ -e ".[\"$field\"]" > /dev/null 2>&1; then
            elog "缺少必需字段: $field"
            return 1
        fi
    done
    local target=$(echo "$metadata" | $JQ -r '.target')
    if [[ "$target" != "a1" && "$target" != "a1ctl" && "$target" != "a1-return" && "$target" != "a1module" && "$target" != "all" ]]; then
        elog "target 字段必須是 'a1', 'a1ctl', 'a1-return', 'a1module', 或 'all'"
        return 1
    fi
    return 0
}

_a1mod_check_depends() {
	local metadata="$1"
	local package="$2"
	# 檢查模塊依賴
	local module_depends=$(echo "$metadata" | $JQ -r '.depends // empty' 2>/dev/null)
	if [ -n "$module_depends" ] && [ "$module_depends" != "null" ]; then
		ilog "檢查模塊依賴中..."
		# 處理數組或字符串
		local depends_list=()
		if echo "$module_depends" | $JQ -e 'type == "array"' >/dev/null 2>&1; then
			# 數組格式
			depends_list=($(echo "$module_depends" | $JQ -r '.[]'))
		else
			depends_list=("$module_depends")
		fi
		for dep in "${depends_list[@]}"; do
			if [ -z "$dep" ] || [ "$dep" = "null" ]; then
				continue
			fi
			# 檢查模塊是否已安裝
			local installed=$($JQ -r \
				".modules.official[\"$dep\"] // .modules.user[\"$dep\"] // empty" \
				"$MODULE_DB" 2>/dev/null)
			if [ -z "$installed" ]; then
				elog "缺少依賴模塊: $dep"
				echo "  請先安裝: $dep"
				return 1
			else
				local dep_version=$(echo "$installed" | $JQ -r '.version // "unknown"')
				ilog "依賴滿足: $dep (v$dep_version)"
			fi
		done
	fi
    return 0
}

_a1mod_check_apt_depends() {
	local metadata="$1"
	local package="$2"
	# 檢查 APT 依賴
	local apt_depends=$(echo "$metadata" | $JQ -r '.depends_apt // empty' 2>/dev/null)
	if [ -n "$apt_depends" ] && [ "$apt_depends" != "null" ]; then
		ilog "檢查依賴中..."
		# 處理數組或字符串格式
		local apt_list=()
		if echo "$apt_depends" | $JQ -e 'type == "array"' >/dev/null 2>&1; then
			# 數組格式
			apt_list=($(echo "$apt_depends" | $JQ -r '.[]'))
		else
			# 字符串格式
			apt_list=("$apt_depends")
		fi
		local missing_pkgs=()
		for pkg in "${apt_list[@]}"; do
			if [ -z "$pkg" ] || [ "$pkg" = "null" ]; then
				continue
			fi
			# 清理包名(移除版本號)
			local clean_pkg=$(echo "$pkg" | sed 's/[<>=].*//')
			if dpkg -l "$clean_pkg" 2>/dev/null | grep -q "^ii"; then
				local installed_version=$(dpkg -s "$clean_pkg" 2>/dev/null | grep "Version:" | cut -d: -f2 | xargs)
				ilog "已安裝: $clean_pkg ($installed_version)"
			else
				wlog "未安裝: $clean_pkg"
				missing_pkgs+=("$pkg")
			fi
		done
		# 提示安裝缺失的包
		if [ ${#missing_pkgs[@]} -gt 0 ]; then
			wlog "缺少以下依賴:"
			for pkg in "${missing_pkgs[@]}"; do
				echo "  - $pkg"
			done
			wlog "建議使用以下命令安裝:"
			echo "  apt update && apt install ${missing_pkgs[*]}"
			read -p "是否嘗試自動安裝?(y/N): " confirm
			if [[ "$confirm" =~ ^[Yy]$ ]]; then
				if [[ $EUID -ne 0 ]]; then
					elog "此操作需要root權限才能執行, 請使用sudo或者a1hub來執行"
					return 1
				fi
				ilog "嘗試安裝依賴中..."
				apt update && apt install -y "${missing_pkgs[@]}"
				# 重新檢查
				local still_missing=()
				for pkg in "${missing_pkgs[@]}"; do
					local clean_pkg=$(echo "$pkg" | sed 's/[<>=].*//')
					if ! dpkg -l "$clean_pkg" 2>/dev/null | grep -q "^ii"; then
						still_missing+=("$pkg")
					fi
				done
				if [ ${#still_missing[@]} -gt 0 ]; then
					elog "無法安裝以下依賴:"
					for pkg in "${still_missing[@]}"; do						cerr "  - $pkg"
					done
					elog "請手動安裝後重試"
					return 1
				fi
			else
				wlog "請手動安裝依賴後繼續"
				return 1
			fi
		fi
	fi
	return 0
}

_a1mod_check_conflict() {
    local package="$1"
    local author="$2"
    local existing=$($JQ -r \
        ".modules.official[\"$package\"] // .modules.user[\"$package\"] // empty" \
        "$MODULE_DB" 2>/dev/null)
    if [ -n "$existing" ]; then
        local existing_author=$(echo "$existing" | $JQ -r '.author')
        if [ "$existing_author" = "$author" ]; then
            echo "same_author"
        else
            echo "different_author"
        fi
        return 1
    fi
    return 0
}

