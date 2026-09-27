#generate-version.sh
generate_version() {
    local script_path="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"
    source "${script_path}/env.sh"

    a1_version=""
    a1ctl_version=""
    a1mod_version=""
    a1pm_version=""
    gui_version=""
    general_version=""
    temp_file=$(mktemp)

    local include_set=""
    local -A exclude_map=()
    local arg

    for arg in "$@"
    do
        case "$arg" in
            --no-a1)      exclude_map[a1]=1 ;;
            --no-a1ctl)   exclude_map[a1ctl]=1 ;;
            --no-a1mod)   exclude_map[a1mod]=1 ;;
            --no-a1pm)    exclude_map[a1pm]=1 ;;
            --no-gui)     exclude_map[gui]=1 ;;
            --no-general) exclude_map[general]=1 ;;
            --no-*)       echo "[Error]: unknown option: $arg" >&2; rm -f "$temp_file"; return 1 ;;
            all|"")       include_set="all" ;;
            a1|a1ctl|a1mod|a1pm|gui|general)
                          include_set="${include_set:+$include_set,}$arg" ;;
            *)            echo "[Error]: unsupported parameter: $arg" >&2; rm -f "$temp_file"; return 1 ;;
        esac
    done

    _should_update() {
        local key="$1"
        [[ -n "${exclude_map[$key]}" ]] && return 1
        [[ -z "$include_set" || "$include_set" == "all" ]] && return 0
        [[ ",$include_set," == *",$key,"* ]] && return 0
        return 1
    }

    while IFS= read -r line || [[ -n "$line" ]]
    do
        if [[ "$line" =~ ^\[new_version\]$ ]]; then
            in_new_section=1
            echo "$line" >> "$temp_file"
            continue
        fi
        if [[ "$line" =~ ^\[.+\]$ ]] && [[ -n "$in_new_section" ]]; then
            in_new_section=0
        fi
        if [[ -n "$in_new_section" ]] && \
           [[ "$line" =~ ^(a1_version|a1ctl_version|a1mod_version|a1pm_version|gui_version|general_version)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
            local short
            case "$key" in
                a1_version)      short="a1" ;;
                a1ctl_version)   short="a1ctl" ;;
                a1mod_version)   short="a1mod" ;;
                a1pm_version)    short="a1pm" ;;
                gui_version)     short="gui" ;;
                general_version) short="general" ;;
            esac

            should_update=0
            _should_update "$short" && should_update=1

            if [[ $should_update -eq 1 ]] && [[ "$value" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(\.([0-9]+))?(-([^+]+))?(\+(.+))?$ ]]; then
                major="${BASH_REMATCH[1]}"
                minor="${BASH_REMATCH[2]}"
                patch="${BASH_REMATCH[3]}"
                build="${BASH_REMATCH[5]}"
                prerelease="${BASH_REMATCH[7]}"
                metadata="${BASH_REMATCH[9]}"
                if [[ -n "$build" ]]; then
                    build=$((build + 1))
                fi
                new_value="${major}.${minor}.${patch}"
                [[ -n "$build" ]] && new_value="${new_value}.${build}"
                [[ -n "$prerelease" ]] && new_value="${new_value}-${prerelease}"
                [[ -n "$metadata" ]] && new_value="${new_value}+${metadata}"
            else
                new_value="$value"
            fi
            echo "${key} = ${new_value}" >> "$temp_file"
            case "$key" in
                a1_version) a1_version="$new_value"; ;;
                a1ctl_version) a1ctl_version="$new_value"; ;;
                a1mod_version) a1mod_version="$new_value"; ;;
                a1pm_version) a1pm_version="$new_value"; ;;
                gui_version) gui_version="$new_value"; ;;
                general_version) general_version="$new_value"; ;;
            esac
        else
            echo "$line" >> "$temp_file"
        fi
    done < "${script_path}/../version.ini"

    mv "$temp_file" "${script_path}/../version.ini"

    if [ -z "$a1_version" ]      || \
       [ -z "$a1ctl_version" ]   || \
       [ -z "$a1mod_version" ]   || \
       [ -z "$a1pm_version" ]    || \
       [ -z "$gui_version" ]     || \
       [ -z "$general_version" ]; then
        while IFS='=' read -r key value
        do
            key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')
            case "$key" in
                a1_version) a1_version="$value" ;;
                a1ctl_version) a1ctl_version="$value" ;;
                a1mod_version) a1mod_version="$value" ;;
                a1pm_version) a1pm_version="$value" ;;
                gui_version) gui_version="$value" ;;
                general_version) general_version="$value" ;;
            esac
        done < <(grep -E "^(a1_version|a1ctl_version|a1mod_version|a1pm_version|gui_version|general_version)=" "${script_path}/../version.ini")
    fi

    echo "a1_version=$a1_version"
    echo "a1ctl_version=$a1ctl_version"
    echo "a1mod_version=$a1mod_version"
    echo "a1pm_version=$a1pm_version"
    echo "gui_version=$gui_version"
    echo "general_version=$general_version"

    sed -e "s/@a1_version@/$a1_version/g" \
        -e "s/@a1ctl_version@/$a1ctl_version/g" \
        -e "s/@a1mod_version@/$a1mod_version/g" \
        -e "s/@a1pm_version@/$a1pm_version/g" \
        "${src_path}/a1/core/version.hpp.in" > "${src_path}/a1/core/version.hpp"

    sed -e "s/@version@/$gui_version/g" ${script_path}/../src/gui/Info.plist.in > ${script_path}/../src/gui/Info.plist
}

get_version() {
    local in_new_section=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^\[new_version\][[:space:]]*$ ]]; then
            in_new_section=1
            continue
        fi
        if [[ "$line" =~ ^\[.+\][[:space:]]*$ ]]; then
            in_new_section=0
            continue
        fi
        if [[ $in_new_section -eq 1 ]] && \
           [[ "$line" =~ ^(a1_version|a1ctl_version|a1mod_version|a1pm_version|gui_version|general_version)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
            case "$key" in
                a1_version)    a1_version="$value" ;;
                a1ctl_version) a1ctl_version="$value" ;;
                a1mod_version) a1mod_version="$value" ;;
                a1pm_version)  a1pm_version="$value" ;;
                gui_version)   gui_version="$value" ;;
                general_version) general_version="$value" ;;
            esac
        fi
    done < "${script_path}/../version.ini"
    case $1 in
        "") echo "[Error]: need options" >&2; exit 1; ;;
        a1) printf "%s" "$a1_version" ;;
        a1ctl) printf "%s" "$a1ctl_version" ;;
        a1mod) printf "%s" "$a1mod_version" ;;
        a1pm) printf "%s" "$a1pm_version" ;;
        gui|a1gui) printf "%s" "$gui_version" ;;
        general) printf "%s" "$general_version" ;;
        *) echo "[Error]: unsupported parameters: $1" >&2; exit 1; ;;
    esac
}
