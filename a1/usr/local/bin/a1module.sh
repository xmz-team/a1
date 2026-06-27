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
    builtin printf "%s\n" "$@" >&2
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
    for author in AD LF; do
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
    $JQ -r '.modules.official | to_entries[] | 
          "  \(.key): \(.value.name) (v\(.value.version))\n" +
          "    作者: \(.value.author), 維護者: \(.value.maintainer)\n" +
          "    目標: \(.value.target)\n" +
          "    描述: \(.value.description)\n" +
          "    安裝日期: \(.value.installed_date)\n" +
          (if (.value.depends | length) > 0 then 
               "    模塊依賴:\n" + 
               (.value.depends[] | "      - \(.)") + "\n"
          else "" end) +
          (if (.value.depends_apt | length) > 0 then 
               "    系統依賴:\n" + 
               (.value.depends_apt[] | "      - \(.)") + "\n"
          else "" end) +
          (if (.value.update_log | length) > 0 then 
               "    更新日誌:\n" + 
               (.value.update_log[] | "      - \(.)") + "\n"
          else "" end)' "$MODULE_DB" 2>/dev/null || echo "  暫無官方模組"
    
    echo -e "\n=== 用戶模組 ==="
    $JQ -r '.modules.user | to_entries[] | 
          "  \(.key): \(.value.name) (v\(.value.version))\n" +
          "    作者: \(.value.author), 維護者: \(.value.maintainer)\n" +
          "    目標: \(.value.target)\n" +
          "    描述: \(.value.description)\n" +
          "    安裝日期: \(.value.installed_date)\n" +
          (if (.value.depends | length) > 0 then 
               "    模塊依賴:\n" + 
               (.value.depends[] | "      - \(.)") + "\n"
          else "" end) +
          (if (.value.depends_apt | length) > 0 then 
               "    系統依賴:\n" + 
               (.value.depends_apt[] | "      - \(.)") + "\n"
          else "" end) +
          (if (.value.update_log | length) > 0 then 
               "    更新日誌:\n" + 
               (.value.update_log[] | "      - \(.)") + "\n"
          else "" end)' "$MODULE_DB" 2>/dev/null || echo "  暫無用戶模組"
}

enable_module() {
    local module_id="$1"
    
    if ! $JQ -e ".modules.official[\"$module_id\"] or .modules.user[\"$module_id\"]" \
        "$MODULE_DB" > /dev/null 2>&1; then
        cerr "${RED}[Error]${NC}: 模塊不存在: $module_id"
        return 1
    fi
    
    $JQ --arg id "$module_id" \
       '.enabled_modules |= (. + [$id] | unique)' "$ENABLED_DB" > "${ENABLED_DB}.tmp"
    
    if [ $? -eq 0 ]; then
        $MV "${ENABLED_DB}.tmp" "$ENABLED_DB"
        echo -e "${GREEN}✓${NC} 模塊已啟用: $module_id"
    else
        cerr "${RED}[Error]${NC}: 啟用失敗"
        return 1
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

load_modules() { echo "已棄用,不加載模塊,由a1,a1ctl,a1mod自動加載"; }

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

show_help() {
    if [ "$a1ctl_call_mod" = "true" ]; then
        local script_name="a1ctl mod"
    else
        local script_name="$0"
    fi
    local official_modules=$(ls "$a1_expand/official/modules")
    local _show_help="\
usage: $script_name [option] [parameters]
option:
  init                初始化模塊系統
  list                列出所有模塊
  package <目錄>      打包模塊
  pack <目錄>         等同於 package
  install <文件>      安裝模塊
  enable <模塊ID>     啟用模塊
  disable <模塊ID>    禁用模塊
  load                加載啟用的模塊
  remove <模塊ID>     刪除模塊
  help                顯示幫助
其他:
  ====----- 官方擴展包 -----====
  $official_modules
  ====--------------------====
示例:
  $script_name init
  $script_name list
  $script_name package ./my_module
  $script_name install my_module.a1module.zip
  $script_name enable my_module
  $script_name load

"
    printf "$_show_help"
}

load_modules() {
    source "$jb_a1/load_mod.sh"
    load_modules_common "a1module"
}

main() {
    check_commands
    load_modules >/dev/null
    echo "a1module module loaded/open"
    local command="${1:-help}"
    
    case "$command" in
        init)       init_system ;;
        list)       list_modules ;;
        package|pack)
            if [ -z "$2" ]; then
                cerr "${RED}[Error]${NC}: 請指定要打包的目錄"
                exit 1
            fi
            package_module "$2" "${3:-.}"
            ;;
        install)
            if [ -z "$2" ]; then
                cerr "${RED}[Error]${NC}: 請指定要安裝的模塊文件"
                exit 1
            fi
            install_module "$2" "${3:-false}"
            ;;
        enable)
            if [ -z "$2" ]; then
                cerr "${RED}[Error]${NC}: 請指定要啟用的模塊ID"
                exit 1
            fi
            enable_module "$2"
            ;;
        disable)
            if [ -z "$2" ]; then
                cerr "${RED}[Error]${NC}: 請指定要禁用的模塊ID"
                exit 1
            fi
            disable_module "$2"
            ;;
        load)       load_modules ;;
        remove)
            if [ -z "$2" ]; then
                cerr "${RED}[Error]${NC}: 請指定要刪除的模塊ID"
                exit 1
            fi
            remove_module "$2"
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
