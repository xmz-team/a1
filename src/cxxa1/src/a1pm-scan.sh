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
    if [ "$(dpkg --print-architecture)" = "iphoneos-arm64e" ]; then
        jb="$(jbroot)"
    else
        jb=""
    fi
fi

myini="$jb/a1/bin/myini"
REPO_DIR="${1:-.}"
OUTPUT_FILE="${2:-$REPO_DIR/Packages.ini}"
TEMP_DIR="${TMPDIR:-/tmp}/a1-scan-$$"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

parse_ini_metadata() {
    local metadata_file="$1"
    local section="${2:-metadata}"
    if [ ! -f "$myini" ]; then
        echo -e "${RED}[Error]${NC}: myini not found: $myini" >&2
        return 1
    fi
    local package=$("$myini" get "$metadata_file" "$section.package" 2>/dev/null || echo "")
    local name=$("$myini" get "$metadata_file" "$section.name" 2>/dev/null || echo "")
    local version=$("$myini" get "$metadata_file" "$section.version" 2>/dev/null || echo "")
    local author=$("$myini" get "$metadata_file" "$section.author" 2>/dev/null || echo "")
    local maintainer=$("$myini" get "$metadata_file" "$section.maintainer" 2>/dev/null || echo "")
    local descr=$("$myini" get "$metadata_file" "$section.description" 2>/dev/null || echo "")
    local depends=$("$myini" get "$metadata_file" "$section.depends" 2>/dev/null || echo "")
    local depends_apt=$("$myini" get "$metadata_file" "$section.depends_apt" 2>/dev/null || echo "")
    local section_name=$("$myini" get "$metadata_file" "$section.section" 2>/dev/null || echo "")
    local priority=$("$myini" get "$metadata_file" "$section.priority" 2>/dev/null || echo "")
    echo "$package|$name|$version|$author|$maintainer|$descr|$depends|$depends_apt|$section_name|$priority"
    return 0
}

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

get_file_size() {
    local file="$1"
    stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo ""
}

scan_packages() {
    mkdir -p "$TEMP_DIR"
    local temp_packages="$TEMP_DIR/packages.tmp"
    > "$temp_packages"
    local count=0
    local output_dir=""
    if command -v realpath &>/dev/null; then
        output_dir=$(dirname "$(realpath "$OUTPUT_FILE")")
    else
        output_dir=$(dirname "$OUTPUT_FILE")
        if [[ "$output_dir" != /* ]]; then
            output_dir="$(pwd)/$output_dir"
        fi
    fi
    while IFS= read -r -d '' module_file
    do
        local filename=$(basename "$module_file")
        local extract_dir="$TEMP_DIR/extract_${count}"
        mkdir -p "$extract_dir"
        if ! unzip -q "$module_file" -d "$extract_dir" 2>/dev/null; then
            echo -e "${RED}[Error]${NC}: unzip failed: $filename" >&2
            rm -rf "$extract_dir"
            continue
        fi
        local metadata_file=""
        if [ -f "$extract_dir/control.ini" ]; then
            metadata_file="$extract_dir/control.ini"
        fi
        
        if [ -z "$metadata_file" ] || [ ! -f "$metadata_file" ]; then
            echo -e "${RED}[Error]${NC}: not found control.ini: $filename" >&2
            rm -rf "$extract_dir"
            continue
        fi
        local metadata=$(parse_ini_metadata "$metadata_file" "")
        if [ $? -ne 0 ] || [ -z "$metadata" ]; then
            rm -rf "$extract_dir"
            continue
        fi
        
        IFS='|' read -r package name version author maintainer description depends depends_apt section priority <<< "$metadata"
        if [ -z "$package" ]; then
            echo -e "${RED}[Error]${NC}: missing necessary fields package: $filename" >&2
            rm -rf "$extract_dir"
            continue
        fi
        if [ -z "$version" ]; then
            echo -e "${RED}[Error]${NC}: missing necessary fields version: $filename" >&2
            rm -rf "$extract_dir"
            continue
        fi
        if [ -z "$maintainer" ]; then
            echo -e "${RED}[Error]${NC}: missing necessary fields maintainer: $filename" >&2
            rm -rf "$extract_dir"
            continue
        fi
        if [ -z "$descr" ]; then
            echo -e "${RED}[Error]${NC}: missing necessary fields description: $filename" >&2
            rm -rf "$extract_dir"
            continue
        fi
        local file_size=$(get_file_size "$module_file")
        local sha256=$(compute_sha256 "$module_file")
        local file_path=""
        if command -v realpath &>/dev/null; then
            file_path=$(realpath --relative-to="$output_dir" "$module_file" 2>/dev/null)
        else
            local module_abs=$(cd "$(dirname "$module_file")" && pwd)/$(basename "$module_file")
            file_path="${module_abs#$output_dir/}"
            if [ "$file_path" = "$module_abs" ]; then
                file_path="$filename"
            fi
        fi
        [ -z "$file_path" ] && file_path="$filename"
        descr=$(echo "$descr" | tr '\n' ' ' | sed 's/  */ /g')
        cat >> "$temp_packages" << EOF
[${package}]
package: ${package}
name: ${name:-$package}
version: $version
author: $author
maintainer: $maintainer
section: $section
priority: $priority
filename: $filename
filepath: $file_path
size: $file_size
sha256: $sha256
depends: $depends
depends_apt: $depends_apt
description: $descr

EOF
        count=$((count + 1))
        rm -rf "$extract_dir"
    done < <(find "$REPO_DIR" \( -name "*.a1mod" -o -name "*.a1module.zip" \) -print0 | sort -z)
    if [ $count -gt 0 ]; then
        echo "the file is in: $OUTPUT_FILE"
    else
        echo -e "${RED}[Error]${NC}: no .a1module.zip or .a1mod files were found."
    fi
    if [ -f "$OUTPUT_FILE" ]; then
        local file_size=$(get_file_size "$OUTPUT_FILE")
        echo "Size: $file_size B"
    fi
}

show_help() {
    cat << EOF
Usage: $0 [options] [dir]
options:
  -o, --output FILE     specify the output file (default: Packages.ini)
  -h, --help            Show this help
Tips:
  $0 .                              # Scan the current directory and subdirectories
  $0 . -o ./Packages.ini            # Specify the output file
  $0 ./a1mod -o ./Packages.ini      # Scan the a1mod directory

EOF
}

main() {
    while [[ $# -gt 0 ]]
    do
        case "$1" in
            -o|--output)
                OUTPUT_FILE="$2"; shift 2 ;;
            -h|--help)
                show_help; exit 0 ;;
            -*)
                echo -e "${RED}[Error]${NC}: unknown option: $1" >&2
                show_help; exit 1 ;;
            *)
                REPO_DIR="$1"; shift ;;
        esac
    done
    if [ ! -d "$REPO_DIR" ]; then
        echo -e "${RED}[Error]${NC}: the directory does not exist.: $REPO_DIR" >&2
        exit 1
    fi
    if [[ "$OUTPUT_FILE" != /* ]]; then
        OUTPUT_FILE="$(pwd)/$OUTPUT_FILE"
    fi
    scan_packages
}

main "$@"
