#!/bin/bash

if [ -f '/etc/profile' ]; then
    source /etc/profile
elif [ -f '/var/jb/etc/profile' ]; then
    source /var/jb/etc/profile
else
    echo 'Where the fuck "profile"?' 1>&2
fi

if [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
    jb="/var/jb"
else
    jb=""
fi

jb_a1="$jb/a1"

if [ -n "$jb_a1" ]; then
    if [ -f "$jb_a1/autofonf.ini" ]; then
        source "$jb_a1/autofonf.ini"
    elif [ -f "$jb_a1/a1_ADautoconf.sh" ]; then
        source "$jb_a1/a1_ADautoconf.sh"
        [ -f "$jb_a1/autofonf.ini" ] && source "$jb_a1/autofonf.ini"
    fi
fi

source "$jb_a1/config.conf"
source "$jb_a1/inside.ini"

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
AUTHER="$(cat "$MODULE_BASE/auther")"
LOCK_FILE="$MODULE_BASE/lock"
LOCK_FD=300

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

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cerr() {
    builtin printf "%b\n" "$@" >&2
}

check_commands() {
    local missing=()
    for cmd_var in JQ ZIP UNZIP; do
        local cmd="${!cmd_var}"
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd_var (在 autofonf.ini 中應定義為 ${cmd_var,,})")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        cerr "${RED}[Error]${NC}: 缺少必需命令"
        for item in "${missing[@]}"; do
            cerr "  - $item"
        done
        cerr "請更新 autofonf 來獲取最新的環境"
        exit 1
    fi
}

init_system() {
    echo "初始化模塊系統中..."

    # 創建目錄結構
    $MKDIR -p "$OFFICIAL_DIR" "$USER_DIR" \
             "$STORE_OFFICIAL" "$STORE_USER" \
             "$CACHE_DIR"
    
    # 創建官方作者目錄
    for author in $AUTHOR; do
        $MKDIR -p "$OFFICIAL_DIR/$author"
    done
    
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
        echo -e "${GREEN}✓${NC} 模塊數據庫初始化完成"
    fi
    
    # 初始化啟用狀態文件
    if [ ! -f "$ENABLED_DB" ]; then
        cat > "$ENABLED_DB" << 'EOF'
{
  "enabled_modules": [],
  "disabled_modules": []
}
EOF
        echo -e "${GREEN}✓${NC} 啟用狀態文件初始化完成"
    fi
    
    update_last_modified
}

update_last_modified() {
    local current_date=$($DATE '+%Y-%m-%d')
    $JQ --arg date "$current_date" '.last_updated = $date' "$MODULE_DB" > "${MODULE_DB}.tmp"
    $MV "${MODULE_DB}.tmp" "$MODULE_DB"
}

init_repo_list() {
    if [ ! -f "$REPO_LIST" ]; then
        cat > "$REPO_LIST" << 'EOF'
{
  "repositories": {},
  "last_update": ""
}
EOF
    fi
}

# 10
parse_metadata() {
    local metadata_file="$1"
    
    if [ ! -f "$metadata_file" ]; then
        cerr "${RED}[Error]${NC}: 元數據文件不存在: $metadata_file"
        return 1
    fi
    
	# JSON 格式
	if echo "$metadata_file" | $GREP -q "\.json$"; then
		# 檢查 JSON 是否有效
		if ! $JQ empty "$metadata_file" 2>/dev/null; then
			cerr "${RED}[Error]${NC}: JSON 格式錯誤"
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
            
            echo "$metadata"
            return 0
        fi
        
        cerr "${RED}[Error]${NC}: INI 轉換失敗"
        return 1
    fi
    
    cerr "${RED}[Error]${NC}: 不支持的文件格式"
    return 1
}

check_required() {
    local metadata="$1"
    local required_fields=("package" "mainstream" "version" "description" "target")
    
    for field in "${required_fields[@]}"; do
        if ! echo "$metadata" | $JQ -e ".[\"$field\"]" > /dev/null 2>&1; then
            cerr "${RED}[Error]${NC}: 缺少必需字段: $field"
            return 1
        fi
    done

    local target=$(echo "$metadata" | $JQ -r '.target')
    if [[ "$target" != "a1" && "$target" != "a1ctl" && "$target" != "a1-return" && "$target" != "a1module" && "$target" != "all" ]]; then
        cerr "${RED}[Error]${NC}: target 字段必須是 'a1', 'a1ctl', 'a1-return', 'a1module', 或 'all' 通用字段"
        return 1
    fi

    return 0
}

# 0001
check_depends() {
	local metadata="$1"
	local package="$2"
	# 檢查模塊依賴
	local module_depends=$(echo "$metadata" | $JQ -r '.depends // empty' 2>/dev/null)
	if [ -n "$module_depends" ] && [ "$module_depends" != "null" ]; then
		echo -e "${BLUE}[info]${NC} 檢查模塊依賴中..."
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
				cerr "${RED}[Error]${NC}: 缺少依賴模塊: $dep"
				echo "  請先安裝: $dep"
				return 1
			else
				local dep_version=$(echo "$installed" | $JQ -r '.version // "unknown"')
				echo -e "${GREEN}  ✓${NC} 依賴滿足: $dep (v$dep_version)"
			fi
		done
	fi
	
    return 0
}

check_apt_depends() {
	local metadata="$1"
	local package="$2"
	# 檢查 APT 依賴
	local apt_depends=$(echo "$metadata" | $JQ -r '.depends_apt // empty' 2>/dev/null)
	if [ -n "$apt_depends" ] && [ "$apt_depends" != "null" ]; then
		echo -e "${BLUE}[info]${NC} 檢查依賴中..."
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
				echo -e "${GREEN}[info]${NC} 已安裝: $clean_pkg ($installed_version)"
			else
				echo -e "${YELLOW}[warn]${NC} 未安裝: $clean_pkg"
				missing_pkgs+=("$pkg")
			fi
		done
		
		# 提示安裝缺失的包
		if [ ${#missing_pkgs[@]} -gt 0 ]; then
			echo -e "${YELLOW}[warn]${NC}: 缺少以下依賴:"
			for pkg in "${missing_pkgs[@]}"; do
				echo "  - $pkg"
			done
			
			echo -e "${YELLOW}[info]${NC}:建議使用以下命令安裝:"
			echo "  apt update && apt install ${missing_pkgs[*]}"
			
			read -p "是否嘗試自動安裝?(y/N): " confirm
			if [[ "$confirm" =~ ^[Yy]$ ]]; then
				if [[ $EUID -ne 0 ]]; then
					cerr "${RED}[Error]${NC}此操作需要root權限才能執行,請使用sudo或者a1hub來執行"
					return 1
				fi
				
				echo -e "${BLUE}[info]${NC} 嘗試安裝依賴中..."
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
					cerr "${RED}[Error]${NC}: 無法安裝以下依賴:"
					for pkg in "${still_missing[@]}"; do						cerr "  - $pkg"
					done
					cerr "${RED}[Error]${NC}請手動安裝後重試"
					return 1
				fi
			else
				cerr "${YELLOW}[Warn]${NC}: 請手動安裝依賴後繼續"
				return 1
			fi
		fi
	fi
	
	return 0
}

# 格式化描述/更新日誌顯示
format_display_text() {
    local json="$1"
    local field="$2"
    
    if echo "$json" | $JQ -e ".$field | type == \"array\"" >/dev/null 2>&1; then
        # 數組格式
        # echo "$json" | $JQ -r ".$field[]" | while IFS= read -r line; do
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

package_module() {
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
        cerr "${RED}[Error]${NC}: 未找到元數據文件 (data.json 或 data.ini)"
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
    
    local filename="${package}_${author}_${target}.a1module.zip"
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
    $ZIP -r "$filename" "${package}.a1module" > /dev/null 2>&1
    
    if [ ! -f "$filename" ]; then
        cerr "${RED}[Error]${NC}: 打包失敗"
        $RM -rf "$temp_dir"
        return 1
    fi
    
    $MV "$filename" "$output_file"
    
    $RM -rf "$temp_dir"
    
    echo -e "${GREEN}✓${NC} 打包完成: \n 文件在: $output_file"
}

check_conflict() {
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

install_module() {
    local module_file="$1"
    local force="${2:-false}"
    
    if [ ! -f "$module_file" ]; then
        cerr "${RED}[Error]${NC}: 文件不存在: $module_file"
        return 1
    fi
    
    if ! echo "$module_file" | $GREP -q "\.a1module\.zip$"; then
        cerr "${RED}[Error]${NC}: 必須是 .a1module.zip 文件"
        return 1
    fi
    
    echo -e "${BLUE}[info]${NC} 開始安裝模塊: $(basename "$module_file")"
    
    # 創建臨時目錄
    local temp_dir=$($MKDIR -p "$CACHE_DIR/install" && mktemp -d "$CACHE_DIR/install/XXXXXX")
    
    local module_filename=$(basename "$module_file")
    local expected_package="${module_filename%_*}"
    expected_package="${expected_package%.a1module.zip}"
    
    echo -e "${BLUE}[info]${NC} 解壓模塊文件..."
    if ! $UNZIP -q "$module_file" -d "$temp_dir" 2>/dev/null; then
        cerr "${RED}[Error]${NC}: 解壓失敗"
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
        cerr "${RED}[Error]${NC}: 未找到元數據文件 (data.json 或 data.ini)"
        echo "解壓後的目錄結構:"
        find "$temp_dir" -type f | sed 's/^/  /'
        $RM -rf "$temp_dir"
        return 1
    fi
    
    echo -e "${BLUE}[info]${NC} 解析模塊中..."
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
    
    echo -e "${GREEN}[info]${NC} 模塊信息:"
    echo "  名稱: $name ($package)"
    echo "  作者: $author"
    echo "  版本: $version"

	# 檢查依賴
	echo -e "${BLUE}[info]${NC} 檢查模塊依賴..."
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
                echo -e "${YELLOW}[Warn]${NC}: 模塊已存在,是否更新?"
                read -p "(y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo -e "${BLUE}[info]${NC} 刪除舊版本..."
                    remove_module "$package" 2>/dev/null
                else
                    echo "安裝中止"
                    $RM -rf "$temp_dir"
                    return 1
                fi
                ;;
            "different_author")
                cerr "${RED}[Error]${NC}: 模塊 $package 已存在,作者不同"
                $RM -rf "$temp_dir"
                return 1
                ;;
        esac
    fi
    
    local is_official=false
    if [ "$author" = "AD" ] || [ "$author" = "LF" ]; then
        is_official=true
    fi
    
    local install_base=""
    
    if [ "$is_official" = "true" ]; then
        install_base="$OFFICIAL_DIR/$author/$package"
    else
        install_base="$USER_DIR/$author/$package"
    fi
    
    # 清理舊目錄
    echo -e "${BLUE}[info]${NC} 清理安裝目錄..."
    $RM -rf "$install_base"
    $MKDIR -p "$install_base"
    
    # 複製文件
    echo -e "${BLUE}[info]${NC} 複製文件到: $install_base"
    
    find "$source_dir" -maxdepth 1 -type f \
        ! -name ".*" \
        -exec $CP -v {} "$install_base/" \; 2>/dev/null
    
    find "$source_dir" -maxdepth 1 -type d \
        ! -name "." ! -name ".." ! -name ".*" \
        -exec $CP -rv {} "$install_base/" \; 2>/dev/null
    
    # 確保元數據文件存在
    local ext="${metadata_file##*.}"
    if [ ! -f "$install_base/data.$ext" ]; then
        $CP "$metadata_file" "$install_base/data.$ext"
    fi
    
    # 檢查並修復執行權限
    local sh_files=($(find "$install_base" -name "*.sh" -type f 2>/dev/null))
    
    if [ ${#sh_files[@]} -gt 0 ]; then
        for sh_file in "${sh_files[@]}"; do
            local filename=$(basename "$sh_file")
            if [ -x "$sh_file" ]; then
                # echo "  ✓ $filename (可執行)"
                :
            else
                # echo "  ⚠ $filename (設置執行權限)"
                chmod +x "$sh_file"
            fi
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
    
	# 00031
	: '
    # 添加到數據庫
    add_to_db "$package" "$name" "$author" "$maintainer" \
              "$version" "$description" "$main_script" "$is_official"
    '

	add_to_db "$package" "$name" "$author" "$maintainer" \
			  "$version" "$description" "$main_script" "$is_official" "$metadata"

    echo -e "${BLUE}[info]${NC} 清理臨時文件..."
    $RM -rf "$temp_dir"
    $RM -rf $(basename "$source_dir")
    
    echo -e "\n${GREEN}✓${NC} 模塊安裝完成!"
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
            echo -e "${YELLOW}[Warn]${NC}: 腳本缺少執行權限"
        fi
    else
        echo -e "${YELLOW}[Warn]${NC}: 未找到主腳本,這可能是一個純配置文件模塊"
    fi
    # 最後清理
    cd $install_base/ && $RM -rf "./$package.a1module"
    return 0 # 3
}

add_to_db() {
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
        cerr "${RED}[Error]${NC}: 添加到數據庫失敗"
        return 1
    fi
}

list_modules() {
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

disable_module() {
    local module_id="$1"
    
    $JQ --arg id "$module_id" \
       '.enabled_modules |= (. - [$id])' "$ENABLED_DB" > "${ENABLED_DB}.tmp"
    
    if [ $? -eq 0 ]; then
        $MV "${ENABLED_DB}.tmp" "$ENABLED_DB"
        echo -e "${GREEN}✓${NC} 模塊已禁用: $module_id"
    else
        cerr "${RED}[Error]${NC}: 禁用失敗"
        return 1
    fi
}

# load_modules() { echo "已棄用,不加載模塊,由a1,a1ctl,a1mod自動加載"; }

remove_module() {
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
    local is_official=false
    
    if [ "$author" = "AD" ] || [ "$author" = "LF" ]; then
        is_official=true
    fi
    
    # 確認刪除
    echo -e "${YELLOW}[確認]${NC} 是否刪除模塊: $module_id (作者: $author)"
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
        cerr "${RED}[Error]${NC}: 從數據庫刪除失敗"
        return 1
    fi
    
    # 從啟用列表刪除
    $JQ --arg id "$module_id" \
       '.enabled_modules |= (. - [$id])' "$ENABLED_DB" > "${ENABLED_DB}.tmp"
    
    if [ $? -eq 0 ]; then
        $MV "${ENABLED_DB}.tmp" "$ENABLED_DB"
    fi
    
    echo -e "${GREEN}✓${NC} 模塊已刪除: $module_id"
}

# repo {
add_repo() {
    local name="$1"
    local url="$2"
    local maintainer="${3:-unknown}"
    local description="${4:-}"

    if [ -z "$name" ] || [ -z "$url" ]; then
        cerr "${RED}[Error]${NC}: 用法: add-repo <name> <url> [maintainer] [description]"
        return 1
    fi

    # 标准化 URL
    url="${url%/}"
    
    init_repo_list

    # 备份当前 repos.json
    local repos_backup="${REPO_LIST}.backup"
    $CP "$REPO_LIST" "$repos_backup"

    # 检查是否已存在
    if $JQ -e ".repositories[\"$name\"]" "$REPO_LIST" >/dev/null 2>&1; then
        cerr "${YELLOW}[Warn]${NC}: 仓库 '$name' 已存在，将更新 URL"
    fi

    local repo_entry=$($JQ -n \
        --arg name "$name" \
        --arg url "$url" \
        --arg maintainer "$maintainer" \
        --arg description "$description" \
        --arg date "$($DATE '+%Y-%m-%d %H:%M:%S')" \
        '{
            "url": $url,
            "maintainer": $maintainer,
            "description": $description,
            "added_date": $date,
            "enabled": true,
            "last_sync": ""
        }')

    $JQ --arg name "$name" --argjson entry "$repo_entry" \
        '.repositories[$name] = $entry' \
        "$REPO_LIST" > "${REPO_LIST}.tmp"
    
    if [ $? -eq 0 ]; then
        $MV "${REPO_LIST}.tmp" "$REPO_LIST"
        echo -e "${GREEN}✓${NC} 仓库已添加: $name"
        echo "  URL: $url"
        # 尝试同步仓库元数据
        if ! sync_repo_metadata "$name"; then
            # 同步失败，回滚添加操作
            echo -e "${YELLOW}[Warn]${NC}: 仓库同步失败，正在回滚添加操作..."
            if [ -f "$repos_backup" ]; then
                $MV "$repos_backup" "$REPO_LIST"
                echo -e "${GREEN}✓${NC} 已回滚仓库添加操作"
            fi
            $RM -f "$CACHE_DIR/repos/${name}.repo.json"
            $RM -f "$CACHE_DIR/repos/${name}_Packages.json"
            return 1
        fi
        $RM -f "$repos_backup"
    else
        cerr "${RED}[Error]${NC}: 添加仓库失败"
        # 回滚
        if [ -f "$repos_backup" ]; then
            $MV "$repos_backup" "$REPO_LIST"
            echo "已回滚"
        fi
        return 1
    fi
}

# 删除仓库
remove_repo() {
    local name="$1"
    
    if [ -z "$name" ]; then
        cerr "${RED}[Error]${NC}: 用法: remove_repo <name>"
        return 1
    fi

    if ! $JQ -e ".repositories[\"$name\"]" "$REPO_LIST" >/dev/null 2>&1; then
        cerr "${RED}[Error]${NC}: 仓库不存在: $name"
        return 1
    fi

    $JQ "del(.repositories[\"$name\"])" "$REPO_LIST" > "${REPO_LIST}.tmp"
    $MV "${REPO_LIST}.tmp" "$REPO_LIST"
    
    # 清理缓存的包索引
    $RM -f "$CACHE_DIR/repos/${name}_Packages.json"
    
    echo -e "${GREEN}✓${NC} 仓库已删除: $name"
}

# 列出仓库
list_repos() {
    init_repo_list
    
    echo "=== 已配置的远端仓库 ==="
    local repos=$($JQ -r '.repositories | keys[]' "$REPO_LIST" 2>/dev/null)
    
    if [ -z "$repos" ]; then
        echo "  暂无配置仓库"
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
sync_repo_metadata() {
    local repo_name="$1"
    
    if [ -z "$repo_name" ]; then
        # 同步所有仓库
        init_repo_list
        local repos=$($JQ -r '.repositories | keys[]' "$REPO_LIST" 2>/dev/null)
        for repo in $repos; do
            sync_repo_metadata "$repo"
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
        cerr "${RED}[Error]${NC}: 仓库不存在: $repo_name"
        return 1
    fi

    echo -e "${BLUE}[info]${NC} 同步仓库元数据: $repo_name"
    
    # 创建缓存目录
    $MKDIR -p "$CACHE_DIR/repos"
    
    # 尝试下载 .repo.json
    local repo_meta_url="${repo_url}/.repo.json"
    
    echo "  下载仓库元数据: $repo_meta_url"
    if curl -sL --connect-timeout 10 --max-time 30 "$repo_meta_url" -o "$repo_meta_file" 2>/dev/null; then
        if $JQ empty "$repo_meta_file" 2>/dev/null; then
            # 检查 modules 字段类型
            local modules_type=$(jq -r '.modules | type' "$repo_meta_file" 2>/dev/null)
            local pkg_url=""
            
            if [ "$modules_type" = "string" ]; then
                # 字符串类型：直接使用字符串值
                pkg_url=$($JQ -r '.modules' "$repo_meta_file")
                echo "  检测到字符串格式的 modules 字段: $pkg_url"
            elif [ "$modules_type" = "object" ]; then
                # 对象类型：尝试获取 packages 字段
                pkg_url=$($JQ -r '.modules.packages // "Packages.json"' "$repo_meta_file")
            else
                # 其他情况使用默认值
                pkg_url="Packages.json"
            fi
            
            # 构建包索引 URL
            local pkg_index_url="${repo_url}/${pkg_url}"
            
            echo "  下载包索引: $pkg_index_url"
            if curl -sL --connect-timeout 10 --max-time 60 "$pkg_index_url" -o "$pkg_index_file" 2>/dev/null; then
                if $JQ empty "$pkg_index_file" 2>/dev/null; then
                    # 更新同步时间
                    local current_date=$($DATE '+%Y-%m-%d %H:%M:%S')
                    $JQ --arg name "$repo_name" --arg date "$current_date" \
                        ".repositories[\"$name\"].last_sync = \$date" \
                        "$REPO_LIST" > "${REPO_LIST}.tmp"
                    $MV "${REPO_LIST}.tmp" "$REPO_LIST"
                    
                    local pkg_count=$($JQ 'length' "$pkg_index_file" 2>/dev/null || echo 0)
                    echo -e "${GREEN}✓${NC} 仓库同步完成: $pkg_count 个包"
                    
                    # 清理备份
                    $RM -f "$repo_backup" "$pkg_backup" "$repos_backup"
                    return 0
                else
                    cerr "${RED}[Error]${NC}: 包索引格式无效"
                    # 回滚
                    rollback_sync "$repo_name" "$repo_backup" "$pkg_backup" "$repos_backup"
                    return 1
                fi
            else
                cerr "${YELLOW}[Warn]${NC}: 无法下载包索引: $pkg_index_url"
                # 尝试使用默认 Packages.json
                local default_pkg_url="${repo_url}/Packages.json"
                echo "  尝试使用默认包索引: $default_pkg_url"
                if curl -sL --connect-timeout 10 --max-time 60 "$default_pkg_url" -o "$pkg_index_file" 2>/dev/null; then
                    if $JQ empty "$pkg_index_file" 2>/dev/null; then
                        local current_date=$($DATE '+%Y-%m-%d %H:%M:%S')
                        $JQ --arg name "$repo_name" --arg date "$current_date" \
                            ".repositories[\"$name\"].last_sync = \$date" \
                            "$REPO_LIST" > "${REPO_LIST}.tmp"
                        $MV "${REPO_LIST}.tmp" "$REPO_LIST"
                        local pkg_count=$($JQ 'length' "$pkg_index_file" 2>/dev/null || echo 0)
                        echo -e "${GREEN}✓${NC} 使用默认包索引完成: $pkg_count 个包"
                        $RM -f "$repo_backup" "$pkg_backup" "$repos_backup"
                        return 0
                    else
                        cerr "${RED}[Error]${NC}: 默认包索引格式无效"
                        rollback_sync "$repo_name" "$repo_backup" "$pkg_backup" "$repos_backup"
                        return 1
                    fi
                else
                    cerr "${RED}[Error]${NC}: 无法获取包索引"
                    rollback_sync "$repo_name" "$repo_backup" "$pkg_backup" "$repos_backup"
                    return 1
                fi
            fi
        else
            cerr "${RED}[Error]${NC}: 仓库元数据格式无效"
            rollback_sync "$repo_name" "$repo_backup" "$pkg_backup" "$repos_backup"
            return 1
        fi
    else
        # 如果没有 .repo.json，尝试直接下载 Packages.json
        local pkg_index_url="${repo_url}/Packages.json"
        
        echo "  尝试直接下载包索引: $pkg_index_url"
        if curl -sL --connect-timeout 10 --max-time 60 "$pkg_index_url" -o "$pkg_index_file" 2>/dev/null; then
            if $JQ empty "$pkg_index_file" 2>/dev/null; then
                local current_date=$($DATE '+%Y-%m-%d %H:%M:%S')
                $JQ --arg name "$repo_name" --arg date "$current_date" \
                    ".repositories[\"$name\"].last_sync = \$date" \
                    "$REPO_LIST" > "${REPO_LIST}.tmp"
                $MV "${REPO_LIST}.tmp" "$REPO_LIST"
                local pkg_count=$($JQ 'length' "$pkg_index_file" 2>/dev/null || echo 0)
                echo -e "${GREEN}✓${NC} 直接下载包索引完成: $pkg_count 个包"
                $RM -f "$repo_backup" "$pkg_backup" "$repos_backup"
                return 0
            else
                cerr "${RED}[Error]${NC}: 包索引格式无效"
                rollback_sync "$repo_name" "$repo_backup" "$pkg_backup" "$repos_backup"
                return 1
            fi
        else
            cerr "${RED}[Error]${NC}: 无法连接到仓库: $repo_name"
            rollback_sync "$repo_name" "$repo_backup" "$pkg_backup" "$repos_backup"
            return 1
        fi
    fi
}

# rollback
rollback_sync() {
    local repo_name="$1"
    local repo_backup="$2"
    local pkg_backup="$3"
    local repos_backup="$4"
    
    echo -e "${YELLOW}[Warn]${NC}: 同步失败，正在回滚..."
    
    # 恢复 repos.json
    if [ -f "$repos_backup" ]; then
        $MV "$repos_backup" "$REPO_LIST"
        echo "  ✓ 已恢复仓库列表"
    fi
    
    # 恢复仓库元数据
    if [ -f "$repo_backup" ]; then
        $MV "$repo_backup" "$CACHE_DIR/repos/${repo_name}.repo.json"
        echo "  ✓ 已恢复仓库元数据"
    else
        $RM -f "$CACHE_DIR/repos/${repo_name}.repo.json"
    fi
    
    # 恢复包索引
    if [ -f "$pkg_backup" ]; then
        $MV "$pkg_backup" "$CACHE_DIR/repos/${repo_name}_Packages.json"
        echo "  ✓ 已恢复包索引"
    else
        $RM -f "$CACHE_DIR/repos/${repo_name}_Packages.json"
    fi
    
    # 清理临时文件
    $RM -f "${REPO_LIST}.tmp"
    
    echo -e "${RED}✗${NC} 已回滚到同步前的状态"
}

# 搜索远端包
search_remote() {
    local query="$1"
    local found=false
    
    init_repo_list
    $MKDIR -p "$CACHE_DIR/repos"
    
    echo -e "${BLUE}[info]${NC} 搜索远端包: '$query'"
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
            echo "=== 仓库: $repo ==="
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
        echo "  未找到匹配的包"
        echo "  提示: 使用 'sync' 命令更新包索引"
    fi
}

# 列出远端可用包
list_remote() {
    local repo_filter="$1"
    
    init_repo_list
    $MKDIR -p "$CACHE_DIR/repos"
    
    echo "=== 远端可用包 ==="
    
    local repos
    if [ -n "$repo_filter" ]; then
        repos="$repo_filter"
    else
        repos=$($JQ -r '.repositories | keys[]' "$REPO_LIST" 2>/dev/null)
    fi
    
    for repo in $repos; do
        local pkg_file="$CACHE_DIR/repos/${repo}_Packages.json"
        if [ ! -f "$pkg_file" ]; then
            echo "  仓库 $repo 未同步，请运行: sync"
            continue
        fi
        
        echo ""
        echo "=== $repo ==="
        
        local packages=$($JQ -r '.[] | "\(.package)\t\(.name)\t\(.version)\t\(.author)"' "$pkg_file" 2>/dev/null)
        
        if [ -z "$packages" ]; then
            echo "  暂无包"
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
show_remote_info() {
    local package="$1"
    
    if [ -z "$package" ]; then
        cerr "${RED}[Error]${NC}: 用法: info <package>"
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
            echo "=== 包信息: $package ==="
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
        cerr "${YELLOW}[Warn]${NC}: 未找到包: $package"
        echo "提示: 使用 'sync' 更新索引，或 'search' 搜索包"
        return 1
    fi
}

# 从远端安装
install_remote() {
    local package="$1"
    
    if [ -z "$package" ]; then
        cerr "${RED}[Error]${NC}: 用法: install_remote <package>"
        return 1
    fi
    
    init_repo_list
    
    # 查找包在哪个仓库
    local repos=$($JQ -r '.repositories | keys[]' "$REPO_LIST" 2>/dev/null)
    local found_repo=""
    local pkg_info=""
    
    for repo in $repos; do
        local pkg_file="$CACHE_DIR/repos/${repo}_Packages.json"
        if [ ! -f "$pkg_file" ]; then
            echo -e "${YELLOW}[Warn]${NC}: 仓库 $repo 未同步，正在同步..."
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
        cerr "${RED}[Error]${NC}: 未找到包: $package"
        echo "提示: 使用 'search' 搜索包"
        return 1
    fi
    
    local repo_url=$($JQ -r ".repositories[\"$found_repo\"].url" "$REPO_LIST")
    local filename=$(echo "$pkg_info" | $JQ -r '.filename')
    local download_url="${repo_url}/${filename}"
    local download_path="$CACHE_DIR/downloads/$filename"
    local sha256_expected=$(echo "$pkg_info" | $JQ -r '.sha256 // ""')
    
    $MKDIR -p "$CACHE_DIR/downloads"
    
    echo -e "${BLUE}[info]${NC} 从仓库 '$found_repo' 下载: $package"
    echo "  URL: $download_url"
    
    # 下载包
    if curl -L --progress-bar --connect-timeout 10 --max-time 300 \
        "$download_url" -o "$download_path" 2>/dev/null; then
        
        local file_size=$(stat -f%z "$download_path" 2>/dev/null || stat -c%s "$download_path" 2>/dev/null)
        echo -e "${GREEN}✓${NC} 下载完成 (${file_size} 字节)"
        
        # 验证 SHA256（如果提供）
        if [ -n "$sha256_expected" ]; then
            echo -e "${BLUE}[info]${NC} 验证文件完整性..."
            if command -v shasum &>/dev/null; then
                local sha256_actual=$(shasum -a 256 "$download_path" | cut -d' ' -f1)
                if [ "$sha256_actual" != "$sha256_expected" ]; then
                    cerr "${RED}[Error]${NC}: SHA256 验证失败！"
                    echo "  期望: $sha256_expected"
                    echo "  实际: $sha256_actual"
                    $RM -f "$download_path"
                    return 1
                fi
                echo -e "${GREEN}✓${NC} 文件完整性验证通过"
            else
                echo -e "${YELLOW}[Warn]${NC}: shasum 未安装，跳过验证"
            fi
        fi
        
        # 安装下载的包
        install_module "$download_path"
        local install_result=$?
        
        # 清理下载文件
        $RM -f "$download_path"
        
        return $install_result
    else
        cerr "${RED}[Error]${NC}: 下载失败"
        $RM -f "$download_path"
        return 1
    fi
}

# 检查更新
check_updates() {
    echo -e "${BLUE}[info]${NC} 检查远端更新..."
    
    # 先同步索引
    local repos=$($JQ -r '.repositories | keys[]' "$REPO_LIST" 2>/dev/null)
    for repo in $repos; do
        sync_repo_metadata "$repo" &
    done
    wait
    
    echo ""
    echo "=== 可用更新 ==="
    
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
        echo "  所有模块已是最新版本"
    fi
}

# 升级所有模块
upgrade_modules() {
    local specific_package="$1"
    
    echo -e "${BLUE}[info]${NC} 升级模块..."
    sync_repo_metadata
    
    local repos=$($JQ -r '.repositories | keys[]' "$REPO_LIST" 2>/dev/null)
    local upgraded=false
    
    if [ -n "$specific_package" ]; then
        # 升级特定包
        local package="$specific_package"
        local installed_ver=$($JQ -r \
            ".modules.official[\"$package\"].version // .modules.user[\"$package\"].version" \
            "$MODULE_DB" 2>/dev/null)
        
        if [ -z "$installed_ver" ]; then
            cerr "${RED}[Error]${NC}: 模块未安装: $package"
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
                    remove_module "$package" 2>/dev/null
                    install_remote "$package"
                    upgraded=true
                fi
            done
        done
    fi
    
    if [ "$upgraded" = false ]; then
        echo "  所有模块已是最新版本"
    fi
}

# } end

show_help() {
    if [ "$a1ctl_call_mod" = "true" ]; then
        local script_name="a1ctl mod"
    else
        local script_name="$0"
    fi
    
    local official_modules=$(ls "$a1_expand/official/modules" 2>/dev/null || echo "无")
    
    cat << EOF
用法: $script_name [命令] [参数]

命令:
  === 本地管理 ===
  init                    初始化模块系统
  list                    列出所有已安装模块
  package <目录>          打包模块
  install <文件>          从本地文件安装模块
  remove <模块ID>         删除模块
  enable <模块ID>         启用模块
  disable <模块ID>        禁用模块
  
  === 远端仓库 ===
  repo-add <名称> <URL>   添加远端仓库
  repo-remove <名称>      删除远端仓库
  repo-list               列出所有仓库
  sync [仓库名]           同步仓库索引
  search <关键词>         搜索远端包
  list-remote [仓库]      列出远端可用包
  info <包名>             显示远端包详细信息
  install-remote <包名>   从远端安装包
  upgrade [包名]          升级模块
  check-updates           检查可用更新
  
  === 其他 ===
  help                    显示此帮助信息

官方扩展包:
  $official_modules

示例:
  # 添加仓库并安装
  $script_name repo-add official https://repo.example.com/a1-modules
  $script_name sync
  $script_name search example
  $script_name info example-module
  $script_name install-remote example-module
  
  # 更新系统
  $script_name check-updates
  $script_name upgrade
  
  # 本地管理
  $script_name init
  $script_name list
  $script_name package ./my-module
  $script_name install my-module.a1module.zip
EOF
}

# lock {
cleanup_stale_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local old_pid
        old_pid="$(cat "$LOCK_FILE" 2>/dev/null)"
        if [ -z "$old_pid" ] || ! kill -0 "$old_pid" 2>/dev/null; then
            rm -f "$LOCK_FILE"
        fi
    fi
}

acquire_lock() {
    cleanup_stale_lock
    eval "exec $LOCK_FD>\"$LOCK_FILE\""
    if ! $flock -n $LOCK_FD; then
        local lock_pid
        lock_pid="$(cat "$LOCK_FILE" 2>/dev/null)"
        if [ -n "$lock_pid" ]; then
            cerr "${RED}[Error]${NC}: 进程 $lock_pid 正在持有 lock , 无法继续操作"
            cerr "${YELLOW}[Warn]${NC}: 你可以选择删除 lock 文件来让操作继续执行"
            cerr "${YELLOW}[Warn]${NC}: 但是!我们并不推荐使用此方法, 除非持有进程是僵尸进程等的情况"
        else
             cerr "${RED}[Error]${NC}: 无法获取到 lock"
        fi
        return 1
    fi
    echo "$$" > "$LOCK_FILE"
    return 0
}

release_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_pid
        lock_pid="$(cat "$LOCK_FILE" 2>/dev/null)"
        if [ "$lock_pid" = "$$" ]; then
            rm -f "$LOCK_FILE"
        fi
    fi
    eval "exec $LOCK_FD>&-"
}
# } end

load_modules() {
    source "$jb_a1/load_mod.sh"
    load_modules_common "a1module"
}

main() {
    # get lock
    if ! acquire_lock; then
        exit 1
    fi
    trap release_lock EXIT INT TERM

    check_commands
    load_modules >/dev/null
    # echo "a1module module loaded/open"
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        init) init_system ;;
        list) list_modules ;;
        package|pack)
            if [ -z "$1" ]; then
                cerr "${RED}[Error]${NC}: 請指定要打包的目錄"
                exit 1
            fi
            package_module "$1" "${2:-.}"
            ;;
        install)
            if [ -z "$1" ]; then
                cerr "${RED}[Error]${NC}: 請指定要安裝的模塊文件"
                exit 1
            fi
            install_module "$1" "${2:-false}"
            ;;
        enable)
            if [ -z "$1" ]; then
                cerr "${RED}[Error]${NC}: 請指定要啟用的模塊ID"
                exit 1
            fi
            enable_module "$1"
            ;;
        disable)
            if [ -z "$1" ]; then
                cerr "${RED}[Error]${NC}: 請指定要禁用的模塊ID"
                exit 1
            fi
            disable_module "$1"
            ;;
        load)
            load_modules
            ;;
        remove)
            if [ -z "$1" ]; then
                cerr "${RED}[Error]${NC}: 請指定要刪除的模塊ID"
                exit 1
            fi
            remove_module "$1"
            ;;
        # 远端仓库命令
        repo-add)
            [ -z "$1" ] && { cerr "${RED}[Error]${NC}: 用法: repo-add <name> <url>"; exit 1; }
            add_repo "$1" "${2:-}" "${3:-}" "${4:-}"
            ;;
        repo-remove)
            [ -z "$1" ] && { cerr "${RED}[Error]${NC}: 用法: repo-remove <name>"; exit 1; }
            remove_repo "$1"
            ;;
        repo-list)
            list_repos
            ;;
        sync)
            sync_repo_metadata "$1"
            ;;
        search)
            [ -z "$1" ] && { cerr "${RED}[Error]${NC}: 用法: search <关键词>"; exit 1; }
            search_remote "$1"
            ;;
        list-remote)
            list_remote "$1"
            ;;
        info)
            [ -z "$1" ] && { cerr "${RED}[Error]${NC}: 用法: info <包名>"; exit 1; }
            show_remote_info "$1"
            ;;
        install-remote)
            [ -z "$1" ] && { cerr "${RED}[Error]${NC}: 用法: install-remote <包名>"; exit 1; }
            install_remote "$1"
            ;;
        upgrade)
            upgrade_modules "$1"
            ;;
        check-updates)
            check_updates
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            cerr "${RED}[Error]${NC}: 未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
