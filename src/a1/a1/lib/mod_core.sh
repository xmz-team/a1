# mod_core.sh
# Provides all the core features of A1MOD

_A1ModCoreFilePath=$( cd $(dirname ${BASH_SOURCE[0]} ) && pwd )
source "$_A1ModCoreFilePath/apis/check_a1mod.sh"
source "$_A1ModCoreFilePath/lock.sh"
source "$_A1ModCoreFilePath/apis/log.sh"

# 基础目录配置
MODULE_BASE="$a1_expand"
MODULE_DB="$MODULE_BASE/module.list.json"
ENABLED_DB="$MODULE_BASE/enabled.json"
OFFICIAL_DIR="$MODULE_BASE/official"
USER_DIR="$MODULE_BASE/user"
OFFICIAL_MODULES_DIR="$OFFICIAL_DIR"
USER_MODULES_DIR="$USER_DIR"
STORE_DIR="$MODULE_BASE/store"
STORE_OFFICIAL="$STORE_DIR/official"
STORE_USER="$STORE_DIR/user"
CACHE_DIR="$MODULE_BASE/cache"
# 仓库列表文件
REPO_LIST="$MODULE_BASE/repos.json"
# AUTHER="$(cat "$MODULE_BASE/auther")"
LOCK_FILE="$MODULE_BASE/lock"
LOCK_FD=100

JQ="${jq:-jq}"
ZIP="${zip:-zip}"
UNZIP="${unzip:-unzip}"
FIND="${find:-find}"
GREP="${grep:-grep}"
SED="${sed:-sed}"
MKDIR="${mkdir:-mkdir}"
RM="${rm:-rm}"
MV="${mv:-mv}"
CP="${cp:-cp}"
DATE="${date:-date}"
# Color
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

_a1mod_check_commands() {
    local missing=()
    for cmd_var in JQ ZIP UNZIP; do
        local cmd="${!cmd_var}"
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd_var (在 autofonf.ini 中應定義為 ${cmd_var,,})")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        elog "缺少必需命令"
        for item in "${missing[@]}"; do
            cerr "  - $item"
        done
        wlog "請更新 autofonf 來獲取最新的環境"
        exit 1
    fi
}

_a1mod_init_system() {
    ilog "初始化模塊系統中..."
    # 創建目錄結構
    $MKDIR -p "$OFFICIAL_DIR" "$USER_DIR" \
             "$STORE_OFFICIAL" "$STORE_USER" \
             "$CACHE_DIR"
    local auther_json="$MODULE_BASE/auther.json"
    if [ ! -f "$auther_json" ]; then
        cat > "$auther_json" << 'EOF'
{
    "official_authors": [
      "AD",
      "LF",
      "XMZ"
    ]
}
EOF
        ilog "作者配置文件初始化完成"
    fi
    # 從 JSON 配置文件讀取官方作者列表並創建目錄
    if $JQ empty "$auther_json" 2>/dev/null; then
        while IFS= read -r author; do
            if [ -n "$author" ]; then
                $MKDIR -p "$OFFICIAL_DIR/$author"
            fi
        done < <($JQ -r '.official_authors[]' "$auther_json" 2>/dev/null)
    else
        wlog "auther.json 格式錯誤, 未能解析官方作者列表"
    fi
    # 初始化模塊數據庫
    if [ ! -f "$MODULE_DB" ]; then
        cat > "$MODULE_DB" << 'EOF'
{
  "version": "1.0",
  "last_updated": "",
  "modules": {
    "official": {},
    "user": {}
  }
}
EOF
        ilog "模塊數據庫初始化完成"
    fi
    # 初始化啟用狀態文件
    if [ ! -f "$ENABLED_DB" ]; then
        cat > "$ENABLED_DB" << 'EOF'
{
  "enabled_modules": [],
  "disabled_modules": []
}
EOF
        ilog "啟用狀態文件初始化完成"
    fi
    _a1mod_update_last_modified
}

_a1mod_update_last_modified() {
    local current_date=$($DATE '+%Y-%m-%d')
    $JQ --arg date "$current_date" '.last_updated = $date' "$MODULE_DB" > "${MODULE_DB}.tmp"
    $MV "${MODULE_DB}.tmp" "$MODULE_DB"
}

_a1mod_parse_metadata() {
    local metadata_file="$1"
    if [ ! -f "$metadata_file" ]; then
        elog "元數據文件不存在: $metadata_file"
        return 1
    fi
	# JSON 格式
   if echo "$metadata_file" | $GREP -q "\.json$"; then
		# 檢查 JSON 是否有效
		if ! $JQ empty "$metadata_file" 2>/dev/null; then
			elog "JSON 格式錯誤"
			return 1
		fi
		# 讀取 JSON
		local metadata=$(cat "$metadata_file")
		# 處理 description 字段（字符串轉數組）
		if echo "$metadata" | $JQ -e '.description | type == "string"' >/dev/null 2>&1; then
			# 如果是字符串且包含換行符,轉換為數組
			if echo "$metadata" | $JQ -r '.description' | $GREP -q $'\n'; then
				metadata=$(echo "$metadata" | $JQ '
					.description |= (
						if type == "string" then
							split("\n") | map(select(. != ""))
						else . end
					)
				')
			fi
		fi
		# 轉換 update_log 為數組格式
		if echo "$metadata" | $JQ -e '.update_log | type == "string"' >/dev/null 2>&1; then
			metadata=$(echo "$metadata" | $JQ '
				.update_log |= (
					if type == "string" then
						split("\n") | map(select(. != ""))
					else . end
				)
			')
		fi
		# 處理 depends 字段（字符串轉數組）
		if echo "$metadata" | $JQ -e '.depends | type == "string"' >/dev/null 2>&1; then
			metadata=$(echo "$metadata" | $JQ '
				.depends |= (
					if type == "string" then
						split("\n") | map(select(. != ""))
					else . end
				)
			')
		fi
		# 處理 depends_apt 字段(字符串轉數組)
		if echo "$metadata" | $JQ -e '.depends_apt | type == "string"' >/dev/null 2>&1; then
			metadata=$(echo "$metadata" | $JQ '
				.depends_apt |= (
					if type == "string" then
						split("\n") | map(select(. != ""))
					else . end
				)
			')
		fi
		echo "$metadata"
		return 0
		fi
    # INI 格式
    if echo "$metadata_file" | $GREP -q "\.ini$"; then
        # 讀取 INI 文件
        local ini_content=$(cat "$metadata_file")
				local json='{'
        local current_key=""
        local current_value=""
        local in_multiline=false
        while IFS= read -r line; do
            # 清理行
            line=$(echo "$line" | $SED 's/^[[:space:]]*//;s/[[:space:]]*$//')
            # 跳过注释和空行
            [[ -z "$line" ]] && continue
            [[ "${line:0:1}" = "#" ]] && continue
            # 檢查是否是 key: value 格式
            if [[ "$line" =~ ^([^: ]+):(.*)$ ]]; then
                # 處理之前的多行值
                if [ "$in_multiline" = true ] && [ -n "$current_key" ]; then
                    # 清理多行值
                    current_value=$(echo "$current_value" | $SED 's/\\n$//')
                    current_value=$($JQ -aR . <<< "$current_value" | $SED 's/^"//;s/"$//')
                    json+="\"$current_key\":\"$current_value\","
                    in_multiline=false
                fi
                current_key="${BASH_REMATCH[1]}"
                current_key=$(echo "$current_key" | $SED 's/[[:space:]]*$//')
                
                local line_value="${BASH_REMATCH[2]}"
                line_value=$(echo "$line_value" | $SED 's/^[[:space:]]*//')
                # 如果值為空,可能是多行開始
                if [ -z "$line_value" ]; then
                    in_multiline=true
                    current_value=""
                else
                    # 單行值
                    line_value=$($JQ -aR . <<< "$line_value" | $SED 's/^"//;s/"$//')
                    json+="\"$current_key\":\"$line_value\","
                fi
            elif [ "$in_multiline" = true ]; then
                # 多行內容
                current_value+="$line\\n"
            fi
        done <<< "$ini_content"
        # 處理最後的多行值
        if [ "$in_multiline" = true ] && [ -n "$current_key" ]; then
            current_value=$(echo "$current_value" | $SED 's/\\n$//')
            current_value=$($JQ -aR . <<< "$current_value" | $SED 's/^"//;s/"$//')
            json+="\"$current_key\":\"$current_value\","
        fi
        json="${json%,}}"
        # 轉換為 JSON 並處理多行文本為數組
        if echo "$json" | $JQ empty 2>/dev/null; then
            local metadata=$(echo "$json" | $JQ '.')
            # 處理 description 多行文本
            if echo "$metadata" | $JQ -e '.description' >/dev/null 2>&1; then
                metadata=$(echo "$metadata" | $JQ '
                    if .description | type == "string" and contains("\n") then
                        .description |= split("\n") | map(select(. != ""))
                    else . end
                ')
            fi
            # 處理 update_log 多行文本
            if echo "$metadata" | $JQ -e '.update_log' >/dev/null 2>&1; then
                metadata=$(echo "$metadata" | $JQ '
                    if .update_log | type == "string" and contains("\n") then
                        .update_log |= split("\n") | map(select(. != ""))
                    else . end
                ')
            fi
            ilog "$metadata"
            return 0
        fi
        elog "INI 轉換失敗"
        return 1
    fi
    
    cerr "${RED}[Error]${NC}: 不支持的文件格式"
    return 1
}
# 格式化描述/更新日誌顯示
_a1mod_format_display_text() {
    local json="$1"
    local field="$2"
    if echo "$json" | $JQ -e ".$field | type == \"array\"" >/dev/null 2>&1; then
        # 數組格式
	    echo "$json" | $JQ -r ".$field" | while IFS= read -r line; do
            echo "  $line"
        done
    elif echo "$json" | $JQ -e ".$field | type == \"string\"" >/dev/null 2>&1; then
        # 字符串格式
        echo "$json" | $JQ -r ".$field" | while IFS= read -r line; do
            echo "  $line"
        done
    elif echo "$json" | $JQ -e ".$field" >/dev/null 2>&1; then
        echo "$json" | $JQ -c ".$field"
    else
        echo "  (無)"
    fi
}

_a1mod_package_module() {
    local source_dir="$1"
    local output_dir="${2:-.}"
    # 獲取絕對路徑
    source_dir=$(cd "$source_dir" && pwd)
    $MKDIR -p "$output_dir"
    output_dir=$(cd "$output_dir" && pwd)
    if [ ! -d "$source_dir" ]; then
        cerr "${RED}[Error]${NC}: 目錄不存在: $source_dir"
        return 1
    fi
    # 查找元數據文件
    local metadata_file=""
    for file in data.json data.ini; do
        if [ -f "$source_dir/$file" ]; then
            metadata_file="$source_dir/$file"
            break
        fi
    done
    if [ -z "$metadata_file" ]; then
        elog "未找到元數據文件 (data.json 或 data.ini)"
        return 1
    fi
    # 解析元數據
    local metadata=$(parse_metadata "$metadata_file")
    [ $? -ne 0 ] && return 1
    # 檢查必需字段
    check_required "$metadata" || return 1
    # 獲取信息
    local package=$(echo "$metadata" | $JQ -r '.package')
    local author=$(echo "$metadata" | $JQ -r '.author // .mainstream')
    local target=$(echo "$metadata" | $JQ -r '.target // "all"')
    local filename="${package}_${author}_${target}.a1mod"
    local output_file="$output_dir/$filename"
    # 創建臨時目錄
    local temp_dir=$($MKDIR -p "$CACHE_DIR/temp" && mktemp -d "$CACHE_DIR/temp/XXXXXX")
    local module_dir="$temp_dir/${package}.a1module"
    $MKDIR -p "$module_dir"
    cd "$source_dir" || return 1
    $FIND . -maxdepth 1 \
        ! -name ".*" \
        ! -name "." \
        -exec $CP -r {} "$module_dir/" \; 2>/dev/null
    # 打包
    cd "$temp_dir" || return 1
    $ZIP -r "$filename" "${package}.a1mod" > /dev/null 2>&1
    if [ ! -f "$filename" ]; then
        cerr "${RED}[Error]${NC}: 打包失敗"
        $RM -rf "$temp_dir"
        return 1
    fi

    $MV "$filename" "$output_file"
    $RM -rf "$temp_dir"
    ilog "打包完成: \n 文件在: $output_file"
}

_a1mod_add_to_db() {
    local package="$1" name="$2" author="$3" maintainer="$4"
    local version="$5" description="$6" path="$7" is_official="$8"
    local metadata="$9"
    # 從元數據中提取 target
    local target=$(echo "$metadata" | $JQ -r '.target // "all"')
    local depends=$(echo "$metadata" | $JQ -c '.depends // []' 2>/dev/null || echo "[]")
    local depends_apt=$(echo "$metadata" | $JQ -c '.depends_apt // []' 2>/dev/null || echo "[]")
    local update_log=$(echo "$metadata" | $JQ -c '.update_log // []' 2>/dev/null || echo "[]")
    local module_data=$($JQ -n \
        --arg name "$name" \
        --arg author "$author" \
        --arg maintainer "$maintainer" \
        --arg version "$version" \
        --argjson description "$description" \
        --arg path "$path" \
        --arg target "$target" \
        --arg date "$($DATE '+%Y-%m-%d')" \
        --arg install_base "$([ "$is_official" = "true" ] && echo "$OFFICIAL_DIR/$author/$package" || echo "$USER_DIR/$author/$package")" \
        --argjson depends "$depends" \
        --argjson depends_apt "$depends_apt" \
        --argjson update_log "$update_log" \
        '{
          "name": $name,
          "author": $author,
          "maintainer": $maintainer,
          "version": $version,
          "description": $description,
          "path": $path,
          "target": $target,
          "install_base": $install_base,
          "installed_date": $date,
          "last_updated": $date,
          "depends": $depends,
          "depends_apt": $depends_apt,
          "update_log": $update_log
        }')
    if [ "$is_official" = "true" ]; then
        $JQ --arg package "$package" \
           --argjson data "$module_data" \
           '.modules.official[$package] = $data' \
           "$MODULE_DB" > "${MODULE_DB}.tmp"
    else
        $JQ --arg package "$package" \
           --argjson data "$module_data" \
           '.modules.user[$package] = $data' \
           "$MODULE_DB" > "${MODULE_DB}.tmp"
    fi
    if [ $? -eq 0 ]; then
        $MV "${MODULE_DB}.tmp" "$MODULE_DB"
        update_last_modified
    else
        elog "添加到數據庫失敗"
        return 1
    fi
}

_a1mod_list_modules() {
    echo "=== 官方模組 ==="
    # 获取所有官方模块的 key
    local keys=$($JQ -r '.modules.official | keys[]' "$MODULE_DB" 2>/dev/null)
    if [ -z "$keys" ]; then
        echo "  暫無官方模組"
    else
        for key in $keys; do
            echo ""
            # 获取模块基本信息
            local name=$($JQ -r ".modules.official[\"$key\"].name" "$MODULE_DB")
            local version=$($JQ -r ".modules.official[\"$key\"].version" "$MODULE_DB")
            local author=$($JQ -r ".modules.official[\"$key\"].author" "$MODULE_DB")
            local maintainer=$($JQ -r ".modules.official[\"$key\"].maintainer" "$MODULE_DB")
            local target=$($JQ -r ".modules.official[\"$key\"].target" "$MODULE_DB")
            local installed_date=$($JQ -r ".modules.official[\"$key\"].installed_date" "$MODULE_DB")
            echo "  $key: $name (v$version)"
            echo "    作者: $author, 維護者: $maintainer"
            echo "    目標: $target"
            echo "    描述:"
            # 单独处理 description 数组
            local desc_count=$($JQ -r ".modules.official[\"$key\"].description | length" "$MODULE_DB" 2>/dev/null)
            if [ -n "$desc_count" ] && [ "$desc_count" -gt 0 ]; then
                $JQ -r ".modules.official[\"$key\"].description[] | \"      - \\(.)\"" "$MODULE_DB"
            else
                echo "      (無描述)"
            fi
            
            echo "    安裝日期: $installed_date"
            # 处理 depends
            local dep_count=$($JQ -r ".modules.official[\"$key\"].depends | length" "$MODULE_DB" 2>/dev/null)
            if [ -n "$dep_count" ] && [ "$dep_count" -gt 0 ]; then
                echo "    模塊依賴:"
                $JQ -r ".modules.official[\"$key\"].depends[] | \"      - \\(.)\"" "$MODULE_DB"
            fi
            # 处理 depends_apt
            local apt_count=$($JQ -r ".modules.official[\"$key\"].depends_apt | length" "$MODULE_DB" 2>/dev/null)
            if [ -n "$apt_count" ] && [ "$apt_count" -gt 0 ]; then
                echo "    系統依賴:"
                $JQ -r ".modules.official[\"$key\"].depends_apt[] | \"      - \\(.)\"" "$MODULE_DB"
            fi
            # 处理 update_log
            local log_count=$($JQ -r ".modules.official[\"$key\"].update_log | length" "$MODULE_DB" 2>/dev/null)
            if [ -n "$log_count" ] && [ "$log_count" -gt 0 ]; then
                echo "    更新日誌:"
                $JQ -r ".modules.official[\"$key\"].update_log[] | \"      - \\(.)\"" "$MODULE_DB"
            fi
        done
    fi
    echo ""
    echo "=== 用戶模組 ==="
    # 用户模块同样处理
    local user_keys=$($JQ -r '.modules.user | keys[]' "$MODULE_DB" 2>/dev/null)
    if [ -z "$user_keys" ]; then
        echo "  暫無用戶模組"
    else
        for key in $user_keys; do
            echo ""
            local name=$($JQ -r ".modules.user[\"$key\"].name" "$MODULE_DB")
            local version=$($JQ -r ".modules.user[\"$key\"].version" "$MODULE_DB")
            local author=$($JQ -r ".modules.user[\"$key\"].author" "$MODULE_DB")
            local maintainer=$($JQ -r ".modules.user[\"$key\"].maintainer" "$MODULE_DB")
            local target=$($JQ -r ".modules.user[\"$key\"].target" "$MODULE_DB")
            local installed_date=$($JQ -r ".modules.user[\"$key\"].installed_date" "$MODULE_DB")
            echo "  $key: $name (v$version)"
            echo "    作者: $author, 維護者: $maintainer"
            echo "    目標: $target"
            echo "    描述:"
            local desc_count=$($JQ -r ".modules.user[\"$key\"].description | length" "$MODULE_DB" 2>/dev/null)
            if [ -n "$desc_count" ] && [ "$desc_count" -gt 0 ]; then
                $JQ -r ".modules.user[\"$key\"].description[] | \"      - \\(.)\"" "$MODULE_DB"
            else
                echo "      (無描述)"
            fi
            echo "    安裝日期: $installed_date"
            local dep_count=$($JQ -r ".modules.user[\"$key\"].depends | length" "$MODULE_DB" 2>/dev/null)
            if [ -n "$dep_count" ] && [ "$dep_count" -gt 0 ]; then
                echo "    模塊依賴:"
                $JQ -r ".modules.user[\"$key\"].depends[] | \"      - \\(.)\"" "$MODULE_DB"
            fi
            local apt_count=$($JQ -r ".modules.user[\"$key\"].depends_apt | length" "$MODULE_DB" 2>/dev/null)
            if [ -n "$apt_count" ] && [ "$apt_count" -gt 0 ]; then
                echo "    系統依賴:"
                $JQ -r ".modules.user[\"$key\"].depends_apt[] | \"      - \\(.)\"" "$MODULE_DB"
            fi
            local log_count=$($JQ -r ".modules.user[\"$key\"].update_log | length" "$MODULE_DB" 2>/dev/null)
            if [ -n "$log_count" ] && [ "$log_count" -gt 0 ]; then
                echo "    更新日誌:"
                $JQ -r ".modules.user[\"$key\"].update_log[] | \"      - \\(.)\"" "$MODULE_DB"
            fi
        done
    fi
}

_a1mod_disable_module() {
    local module_id="$1"
    $JQ --arg id "$module_id" \
       '.enabled_modules |= (. - [$id])' "$ENABLED_DB" > "${ENABLED_DB}.tmp"
    if [ $? -eq 0 ]; then
        $MV "${ENABLED_DB}.tmp" "$ENABLED_DB"
        ilog "模塊已禁用: $module_id"
    else
        elog "禁用失敗"
        return 1
    fi
}

_a1mod_remove_module() {
    local module_id="$1"
    # 獲取模塊信息
    local module_info=$($JQ -r \
        ".modules.official[\"$module_id\"] // 
         .modules.user[\"$module_id\"] // empty" \
        "$MODULE_DB" 2>/dev/null)
    if [ -z "$module_info" ]; then
        cerr "${RED}[Error]${NC}: 模塊不存在: $module_id"
        return 1
    fi
    local author=$(echo "$module_info" | $JQ -r '.author')
    # 通過配置文件判斷是否為官方作者
    local is_official=false
    local auther_json="$MODULE_BASE/auther.json"
    if [ -f "$auther_json" ] && $JQ empty "$auther_json" 2>/dev/null; then
        if $JQ -e --arg auth "$author" '.official_authors[] | select(. == $auth)' "$auther_json" >/dev/null 2>&1; then
            is_official=true
        fi
    fi
    # 確認刪除
    ilog "是否刪除模塊: $module_id (作者: $author)"
    read -p "(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "刪除取消"
        return 0
    fi
    # 從數據庫刪除
    if [ "$is_official" = "true" ]; then
        $JQ "del(.modules.official[\"$module_id\"])" \
            "$MODULE_DB" > "${MODULE_DB}.tmp"
    else
        $JQ "del(.modules.user[\"$module_id\"])" \
            "$MODULE_DB" > "${MODULE_DB}.tmp"
    fi
    if [ $? -eq 0 ]; then
        $MV "${MODULE_DB}.tmp" "$MODULE_DB"
    else
        wlog "從數據庫刪除失敗"
        return 1
    fi
    # 從啟用列表刪除
    $JQ --arg id "$module_id" \
       '.enabled_modules |= (. - [$id])' "$ENABLED_DB" > "${ENABLED_DB}.tmp"
    if [ $? -eq 0 ]; then
        $MV "${ENABLED_DB}.tmp" "$ENABLED_DB"
    fi
    ilog "模塊已刪除: $module_id"
}

_a1mod_install_module() {
    local module_file="$1"
    local force="${2:-false}"
    if [ ! -f "$module_file" ]; then
        elog "文件不存在: $module_file"
        return 1
    fi
    if ! echo "$module_file" | $GREP -q "\.a1mod$" && ! echo "$module_file" | $GREP -q "\.a1module\.zip$"; then
        elog "必須是 .a1module.zip 或 .a1mod 文件"
        return 1
    fi
    ilog "開始安裝模塊: $(basename "$module_file")"
    # 創建臨時目錄
    local temp_dir=$($MKDIR -p "$CACHE_DIR/install" && mktemp -d "$CACHE_DIR/install/XXXXXX")
    local module_filename=$(basename "$module_file")
    local expected_package="${module_filename%_*}"
    if [[ "$module_filename" == *.a1mod ]]; then
        expected_package="${expected_package%.a1mod}"
    else
        expected_package="${expected_package%.a1module.zip}"
    fi
    ilog "解壓模塊文件..."
    if ! $UNZIP -q "$module_file" -d "$temp_dir" 2>/dev/null; then
        elog "解壓失敗"
        $RM -rf "$temp_dir"
        return 1
    fi
    local metadata_file=""
    local source_dir=""
    if [ -f "$temp_dir/data.json" ]; then
        metadata_file="$temp_dir/data.json"
        source_dir="$temp_dir"
    elif [ -f "$temp_dir/data.ini" ]; then
        metadata_file="$temp_dir/data.ini"
        source_dir="$temp_dir"
    else
        local a1module_dirs=()
        while IFS= read -r dir; do
            a1module_dirs+=("$dir")
        done < <(find "$temp_dir" -type d -name "*.a1module" 2>/dev/null)
        if [ ${#a1module_dirs[@]} -eq 1 ]; then
            source_dir="${a1module_dirs[0]}"
            if [ -f "$source_dir/data.json" ]; then
                metadata_file="$source_dir/data.json"
            elif [ -f "$source_dir/data.ini" ]; then
                metadata_file="$source_dir/data.ini"
            fi
        elif [ ${#a1module_dirs[@]} -gt 1 ]; then
            for dir in "${a1module_dirs[@]}"; do
                local dir_name=$(basename "$dir")
                if [[ "$dir_name" == "$expected_package.a1module" ]] || 
                   [[ "$dir_name" == *".$expected_package.a1module" ]]; then
                    source_dir="$dir"
                    break
                fi
            done
            if [ -z "$source_dir" ]; then
                source_dir="${a1module_dirs[0]}"
            fi
            if [ -f "$source_dir/data.json" ]; then
                metadata_file="$source_dir/data.json"
            elif [ -f "$source_dir/data.ini" ]; then
                metadata_file="$source_dir/data.ini"
            fi
        fi
    fi
    if [ -z "$metadata_file" ] || [ -z "$source_dir" ]; then
        elog "未找到元數據文件 (data.json 或 data.ini)"
        echo "解壓後的目錄結構:"
        find "$temp_dir" -type f | sed 's/^/  /'
        $RM -rf "$temp_dir"
        return 1
    fi
    ilog "解析模塊中..."
    local metadata=$(parse_metadata "$metadata_file")
    if [ $? -ne 0 ]; then
        $RM -rf "$temp_dir"
        return 1
    fi
    check_required "$metadata" || {
        $RM -rf "$temp_dir"
        return 1
    }
    local package=$(echo "$metadata" | $JQ -r '.package')
    local name=$(echo "$metadata" | $JQ -r '.name // .package')
    local author=$(echo "$metadata" | $JQ -r '.author // .mainstream')
    local maintainer=$(echo "$metadata" | $JQ -r '.mainstream')
    local version=$(echo "$metadata" | $JQ -r '.version')
    local description=$(echo "$metadata" | $JQ -r '.description // ""')
    ilog "模塊信息:"
    echo "  名稱: $name ($package)"
    echo "  作者: $author"
    echo "  版本: $version"
		# 檢查依賴
		ilog "檢查模塊依賴..."
		check_depends "$metadata" "$package" || {
			$RM -rf "$temp_dir"
			return 1
		}
		check_apt_depends "$metadata" "$package" || {
			$RM -rf "$temp_dir"
			return 1
		}
    # 檢查衝突
    local conflict_result=$(check_conflict "$package" "$author")
    if [ $? -ne 0 ]; then
        case "$conflict_result" in
            "same_author")
                wlog "模塊已存在,是否更新?"
                read -p "(y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    ilog "刪除舊版本..."
                    remove_module "$package" 2>/dev/null
                else
                    ilog "安裝中止"
                    $RM -rf "$temp_dir"
                    return 1
                fi
                ;;
            "different_author")
                elog "模塊 $package 已存在, 作者不同"
                $RM -rf "$temp_dir"
                return 1
                ;;
        esac
    fi
    # 通過配置文件判斷是否為官方作者
    local is_official=false
    local auther_json="$MODULE_BASE/auther.json"
    if [ -f "$auther_json" ] && $JQ empty "$auther_json" 2>/dev/null; then
        if $JQ -e --arg auth "$author" '.official_authors[] | select(. == $auth)' "$auther_json" >/dev/null 2>&1; then
            is_official=true
        fi
    fi
    local install_base=""
    if [ "$is_official" = "true" ]; then
        install_base="$OFFICIAL_DIR/$author/$package"
    else
        install_base="$USER_DIR/$author/$package"
    fi
    ilog "清理安裝目錄..."
    $RM -rf "$install_base"
    $MKDIR -p "$install_base"
    ilog "複製文件到: $install_base"
    find "$source_dir" -maxdepth 1 -type f \
        ! -name ".*" \
        -exec $CP -v {} "$install_base/" \; 2>/dev/null
    find "$source_dir" -maxdepth 1 -type d \
        ! -name "." ! -name ".." ! -name ".*" \
        -exec $CP -rv {} "$install_base/" \; 2>/dev/null
    local ext="${metadata_file##*.}"
    if [ ! -f "$install_base/data.$ext" ]; then
        $CP "$metadata_file" "$install_base/data.$ext"
    fi
    # 檢查並修復執行權限
    local sh_files=($(find "$install_base" -name "*.sh" -type f 2>/dev/null))
    if [ ${#sh_files[@]} -gt 0 ]; then
        for sh_file in "${sh_files[@]}"; do
            local filename=$(basename "$sh_file")
            [ ! -x "$sh_file" ] && chmod +x "$sh_file"
        done
    fi
    local main_script=""
    local possible_main_scripts=(
        "$install_base/$package.sh"
        "$install_base/$package.sh"
        "$install_base/$package.sh"
        "$install_base/$package.sh"
    )
    for script in "${possible_main_scripts[@]}"; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            main_script="$script"
            break
        elif [ -f "$script" ]; then
            main_script="$script"
            chmod +x "$main_script"
            break
        fi
    done
    if [ -z "$main_script" ] && [ ${#sh_files[@]} -gt 0 ]; then
        main_script="${sh_files[0]}"
    fi
		_a1mod_add_to_db "$package" "$name" "$author" "$maintainer" \
		"$version" "$description" "$main_script" "$is_official" "$metadata"
    ilog "清理臨時文件..."
    $RM -rf "$temp_dir"
    $RM -rf $(basename "$source_dir")
    ilog "模塊安裝完成!"
    echo "  名稱: $name"
    echo "  包名: $package"
    echo "  版本: $version"
    echo "  作者: $author"
    echo "  類型: $([ "$is_official" = "true" ] && echo "官方" || echo "用戶")"
    echo "  位置: $install_base/"
    if [ -n "$main_script" ]; then
        if [ -x "$main_script" ]; then
            echo "  狀態: 可執行文件"
        else
            wlog "腳本缺少執行權限"
        fi
    else
        wlog "未找到主腳本,這可能是一個純配置文件模塊"
    fi
    cd $install_base/ && $RM -rf "./$package.a1module"
    return 0
}

# api {
# 公共api
check_commands() { _a1mod_check_commands; }
init_system() { _a1mod_init_system; }
update_last_modified() { _a1mod_update_last_modified; }
parse_metadata() { _a1mod_parse_metadata "$@"; }
format_display_text() { _a1mod_format_display_text "$@"; }
package_module() { _a1mod_package_module "$@"; }
add_to_db() { _a1mod_add_to_db "$@"; }
list_modules() { _a1mod_list_modules "$@"; }
disable_module() { _a1mod_disable_module "$@"; }
remove_module() { _a1mod_remove_module "$@"; }
install_module() { _a1mod_install_module "$@"; }
check_required() { _a1mod_check_required "$@"; }
check_depends() { _a1mod_check_depends "$@"; }
check_apt_depends() {_a1mod_check_apt_depends "$@"; }
check_conflict() { _a1mod_check_conflict "$@"; }
# }

# 导出api
export -f _a1mod_check_commands
export -f _a1mod_init_system
export -f _a1mod_update_last_modified
export -f _a1mod_parse_metadata
export -f _a1mod_format_display_text
export -f _a1mod_package_module
export -f _a1mod_add_to_db
export -f _a1mod_list_modules
export -f _a1mod_disable_module
export -f _a1mod_remove_module
export -f _a1mod_install_module

export -f _a1mod_check_required
export -f _a1mod_check_depends
export -f _a1mod_check_apt_depends
export -f _a1mod_check_conflict

