#!/bin/bash

set -e

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

# 配置
REPO_DIR="${1:-.}"
OUTPUT_FILE="${2:-$REPO_DIR/Packages.json}"
TEMP_DIR="${TMPDIR:-/tmp}/a1-scan-$$"
# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

find_jq() {
    for cmd in jq; do
        command -v "$cmd" &>/dev/null && { echo "$cmd"; return 0; }
    done
    return 1
}

JQ=$(find_jq) || { echo -e "${RED}[Error]${NC}: 需要 jq" >&2; exit 1; }

# 解析模块元数据
parse_module_metadata() {
    local module_file="$1"
    local extract_dir="$TEMP_DIR/$(basename "$module_file" .zip)"
    
    mkdir -p "$extract_dir"
    
    if ! unzip -q "$module_file" -d "$extract_dir" 2>/dev/null; then
        echo -e "${RED}[Error]${NC}: 解压失败: $(basename "$module_file")" >&2
        return 1
    fi
    
    # 查找元数据文件
    local metadata_file=""
    for f in "$extract_dir/data.json" "$extract_dir/data.ini"; do
        [ -f "$f" ] && { metadata_file="$f"; break; }
    done
    
    # 如果在根目录没找到，在子目录中查找
    if [ -z "$metadata_file" ]; then
        metadata_file=$(find "$extract_dir" -name "data.json" -o -name "data.ini" | head -1)
    fi
    
    if [ -z "$metadata_file" ]; then
        echo -e "${RED}[Error]${NC}: 未找到元数据: $(basename "$module_file")" >&2
        return 1
    fi
    
    # 解析 JSON 格式
    if [[ "$metadata_file" == *.json ]]; then
        if ! $JQ empty "$metadata_file" 2>/dev/null; then
            echo -e "${RED}[Error]${NC}: JSON 格式错误: $(basename "$module_file")" >&2
            return 1
        fi
        
        local metadata=$(cat "$metadata_file")
        
        # 处理字符串字段转数组
        metadata=$(echo "$metadata" | $JQ '
            .description |= if type == "string" then split("\n") | map(select(. != "")) else . // [] end |
            .update_log  |= if type == "string" then split("\n") | map(select(. != "")) else . // [] end |
            .depends     |= if type == "string" then split("\n") | map(select(. != "")) else . // [] end |
            .depends_apt |= if type == "string" then split("\n") | map(select(. != "")) else . // [] end
        ')
        
        echo "$metadata"
        return 0
    fi
    
    # 解析 INI 格式
    if [[ "$metadata_file" == *.ini ]]; then
        local json='{'
        local current_key=""
        local current_value=""
        local in_multiline=false
        
        while IFS= read -r line; do
            line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [[ -z "$line" || "${line:0:1}" == "#" || "${line:0:1}" == ";" ]] && continue
            
            if [[ "$line" =~ ^([^:]+):(.*)$ ]]; then
                if [ "$in_multiline" = true ] && [ -n "$current_key" ]; then
                    current_value=$(echo "$current_value" | sed 's/\\n$//')
                    current_value=$($JQ -aR . <<< "$current_value" | sed 's/^"//;s/"$//')
                    json+="\"$current_key\":\"$current_value\","
                    in_multiline=false
                fi
                
                current_key="${BASH_REMATCH[1]}"
                current_key=$(echo "$current_key" | sed 's/[[:space:]]*$//')
                local line_value="${BASH_REMATCH[2]}"
                line_value=$(echo "$line_value" | sed 's/^[[:space:]]*//')
                
                if [ -z "$line_value" ]; then
                    in_multiline=true
                    current_value=""
                else
                    line_value=$($JQ -aR . <<< "$line_value" | sed 's/^"//;s/"$//')
                    json+="\"$current_key\":\"$line_value\","
                fi
            elif [ "$in_multiline" = true ]; then
                current_value+="$line\\n"
            fi
        done < "$metadata_file"
        
        if [ "$in_multiline" = true ] && [ -n "$current_key" ]; then
            current_value=$(echo "$current_value" | sed 's/\\n$//')
            current_value=$($JQ -aR . <<< "$current_value" | sed 's/^"//;s/"$//')
            json+="\"$current_key\":\"$current_value\","
        fi
        
        json="${json%,}}"
        
        if echo "$json" | $JQ empty 2>/dev/null; then
            local metadata=$(echo "$json" | $JQ '
                .description |= if type == "string" and contains("\n") then split("\n") | map(select(. != "")) else . // [] end |
                .update_log  |= if type == "string" and contains("\n") then split("\n") | map(select(. != "")) else . // [] end |
                .depends     |= if type == "string" and contains("\n") then split("\n") | map(select(. != "")) else . // [] end |
                .depends_apt |= if type == "string" and contains("\n") then split("\n") | map(select(. != "")) else . // [] end
            ')
            echo "$metadata"
            return 0
        fi
        
        echo -e "${RED}[Error]${NC}: INI 转换失败: $(basename "$module_file")" >&2
        return 1
    fi
    
    return 1
}

# 计算文件哈希
compute_sha256() {
    local file="$1"
    if command -v shasum &>/dev/null; then
        shasum -a 256 "$file" | cut -d' ' -f1
    elif command -v sha256sum &>/dev/null; then
        sha256sum "$file" | cut -d' ' -f1
    else
        echo ""
    fi
}

# 主扫描函数
scan_packages() {
    mkdir -p "$TEMP_DIR"
    
    echo -e "${BLUE}[info]${NC} 扫描目录: $REPO_DIR"
    
    local packages_json="["
    local count=0
    local first=true
    
    while IFS= read -r -d '' module_file; do
        local filename=$(basename "$module_file")
        echo -e "${BLUE}[info]${NC} 处理: $filename"
        
        local metadata=$(parse_module_metadata "$module_file")
        if [ $? -ne 0 ] || [ -z "$metadata" ]; then
            echo -e "${YELLOW}[Warn]${NC} 跳过无效模块: $filename"
            continue
        fi
        
        # 提取信息
        local package=$(echo "$metadata" | $JQ -r '.package // ""')
        local name=$(echo "$metadata" | $JQ -r '.name // .package // ""')
        local version=$(echo "$metadata" | $JQ -r '.version // "0.0.0"')
        local author=$(echo "$metadata" | $JQ -r '.author // .mainstream // "unknown"')
        local maintainer=$(echo "$metadata" | $JQ -r '.mainstream // .author // "unknown"')
        local target=$(echo "$metadata" | $JQ -r '.target // "all"')
        local architecture=$(echo "$metadata" | $JQ -r '.architecture // "all"')
        local section=$(echo "$metadata" | $JQ -r '.section // "unknown"')
        local priority=$(echo "$metadata" | $JQ -r '.priority // "optional"')
        local homepage=$(echo "$metadata" | $JQ -r '.homepage // ""')
        local description=$(echo "$metadata" | $JQ -c '.description // []')
        local depends=$(echo "$metadata" | $JQ -c '.depends // []')
        local depends_apt=$(echo "$metadata" | $JQ -c '.depends_apt // []')
        local update_log=$(echo "$metadata" | $JQ -c '.update_log // []')
        
        # 文件信息
        local file_size=$(stat -f%z "$module_file" 2>/dev/null || stat -c%s "$module_file" 2>/dev/null || echo 0)
        local sha256=$(compute_sha256 "$module_file")
        
        [ "$first" = true ] && first=false || packages_json+=","
        
        packages_json+=$($JQ -n \
            --arg package "$package" \
            --arg name "$name" \
            --arg version "$version" \
            --arg architecture "$architecture" \
            --arg maintainer "$maintainer" \
            --arg author "$author" \
            --arg target "$target" \
            --arg filename "$filename" \
            --arg size "$file_size" \
            --arg sha256 "$sha256" \
            --arg section "$section" \
            --arg priority "$priority" \
            --arg homepage "$homepage" \
            --argjson description "$description" \
            --argjson depends "$depends" \
            --argjson depends_apt "$depends_apt" \
            --argjson update_log "$update_log" \
            '{
                package: $package,
                name: $name,
                version: $version,
                architecture: $architecture,
                maintainer: $maintainer,
                author: $author,
                target: $target,
                description: $description,
                depends: $depends,
                depends_apt: $depends_apt,
                filename: $filename,
                size: ($size | tonumber),
                sha256: $sha256,
                section: $section,
                priority: $priority,
                homepage: $homepage,
                update_log: $update_log
            }')
        
        count=$((count + 1))
        echo -e "${GREEN}  ✓${NC} $package ($version)"
        
    done < <(find "$REPO_DIR" -maxdepth 1 -name "*.a1module.zip" -print0 | sort -z)
    
    packages_json+="]"
    
    # 格式化输出
    echo "$packages_json" | $JQ '.' > "$OUTPUT_FILE"
    
    echo ""
    echo -e "${GREEN}✓${NC} 扫描完成: $count 个包"
    echo "  输出: $OUTPUT_FILE"
    
    # 显示统计
    if [ -f "$OUTPUT_FILE" ]; then
        local file_size=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
        echo "  大小: $file_size 字节"
    fi
}

# 生成 .repo.json
generate_repo_meta() {
    local name="${1:-My Repository}"
    local url="${2:-https://example.com/repo}"
    local maintainer="${3:-unknown}"
    local description="${4:-A1 Module Repository}"
    
    cat > "$REPO_DIR/.repo.json" << EOF
{
  "name": "$name",
  "url": "$url",
  "maintainer": "$maintainer",
  "description": "$description",
  "version": "1.0",
  "modules": "Packages.json",
  "last_updated": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF
    echo -e "${GREEN}✓${NC} 已生成 .repo.json"
}

# 帮助信息
show_help() {
    cat << EOF
用法: $0 [选项] [目录]

扫描目录中的 .a1module.zip 文件并生成 Packages.json 索引。

选项:
  -o, --output FILE     指定输出文件 (默认: Packages.json)
  --generate-repo       同时生成 .repo.json
  --repo-name NAME      仓库名称 (用于 .repo.json)
  --repo-url URL        仓库 URL (用于 .repo.json)
  --repo-maintainer M   仓库维护者 (用于 .repo.json)
  --repo-desc DESC      仓库描述 (用于 .repo.json)
  -h, --help            显示帮助

示例:
  $0 /path/to/repo
  $0 /path/to/repo -o /tmp/Packages.json
  $0 . --generate-repo --repo-name "My Repo" --repo-url "https://example.com"

EOF
}

# 主程序
main() {
    local generate_repo=false
    local repo_name=""
    local repo_url=""
    local repo_maintainer=""
    local repo_desc=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output)
                OUTPUT_FILE="$2"; shift 2 ;;
            --generate-repo)
                generate_repo=true; shift ;;
            --repo-name)
                repo_name="$2"; shift 2 ;;
            --repo-url)
                repo_url="$2"; shift 2 ;;
            --repo-maintainer)
                repo_maintainer="$2"; shift 2 ;;
            --repo-desc)
                repo_desc="$2"; shift 2 ;;
            -h|--help)
                show_help; exit 0 ;;
            -*)
                echo -e "${RED}[Error]${NC}: 未知选项: $1" >&2
                show_help; exit 1 ;;
            *)
                REPO_DIR="$1"; shift ;;
        esac
    done
    
    if [ ! -d "$REPO_DIR" ]; then
        echo -e "${RED}[Error]${NC}: 目录不存在: $REPO_DIR" >&2
        exit 1
    fi
    
    OUTPUT_FILE="${OUTPUT_FILE:-$REPO_DIR/Packages.json}"
    
    scan_packages
    
    if [ "$generate_repo" = true ]; then
        generate_repo_meta \
            "${repo_name:-My Repository}" \
            "${repo_url:-https://example.com/repo}" \
            "${repo_maintainer:-unknown}" \
            "${repo_desc:-A1 Module Repository}"
    fi
}

main "$@"
