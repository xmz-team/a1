#generate-version.sh
generate_version() {
    local script_path="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"
    source "${script_path}/env.sh"

    _git_tag_of() {
        local name="$1"
        git tag -l "${name}-v*" --sort=-v:refname | head -n1
    }

    _parse_version() {
        local tag="$1"
        local ver="${tag#*-v}"
        IFS='.' read -r major minor patch build <<< "$ver"
        printf '%s %s %s %s' "$major" "$minor" "$patch" "$build"
    }

    _commit_count_since() {
        local tag="$1"
        git rev-list --count "${tag}..HEAD" 2>/dev/null || echo 0
    }

    _bump() {
        local name="$1"
        local tag
        tag="$(_git_tag_of "$name")"
        if [[ -z "$tag" ]]; then
            echo "[Error]: no tag found for ${name}" >&2
            return 1
        fi
        local major minor patch build
        read -r major minor patch build <<< "$(_parse_version "$tag")"
        local cnt
        cnt="$(_commit_count_since "$tag")"
        local new_build=$((build + cnt))
        printf '%s.%s.%s.%s' "$major" "$minor" "$patch" "$new_build"
    }

    _retag() {
        local name="$1"
        local new_ver="$2"
        local new_tag="${name}-v${new_ver}"
        local old_tag
        old_tag="$(_git_tag_of "$name")"
        if [[ "$old_tag" == "$new_tag" ]]; then
            echo "[Info]: ${name} tag unchanged: ${new_tag}"
            return 0
        fi
        git tag -f "$new_tag" >/dev/null 2>&1
        if git remote get-url origin >/dev/null 2>&1; then
            git push -f origin "$new_tag" >/dev/null 2>&1 || \
                echo "[Warn]: failed to push tag ${new_tag}" >&2
        fi
        if [[ -n "$old_tag" && "$old_tag" != "$new_tag" ]]; then
            git tag -d "$old_tag" >/dev/null 2>&1
            if git remote get-url origin >/dev/null 2>&1; then
                git push origin ":refs/tags/${old_tag}" >/dev/null 2>&1 || true
            fi
        fi
        echo "[Info]: ${name} retagged: ${old_tag} -> ${new_tag}"
    }

    _write_version_ini() {
        local name="$1" ver="$2"
        local key="${name}_version"
        local ini="${script_path}/../version.ini"
        if grep -qE "^${key}[[:space:]]*=" "$ini" 2>/dev/null; then
            sed -i.bak -E "s|^${key}[[:space:]]*=.*|${key} = ${ver}|" "$ini"
            rm -f "${ini}.bak"
        else
            printf '%s = %s\n' "$key" "$ver" >> "$ini"
        fi
    }

    _render_headers() {
        local ini="${script_path}/../version.ini"
        local a1_v a1ctl_v a1mod_v a1pm_v gui_v general_v
        a1_v="$(get_version a1)"
        a1ctl_v="$(get_version a1ctl)"
        a1mod_v="$(get_version a1mod)"
        a1pm_v="$(get_version a1pm)"
        gui_v="$(get_version gui)"
        general_v="$(get_version general)"

        sed -e "s/@a1_version@/${a1_v}/g" \
            -e "s/@a1ctl_version@/${a1ctl_v}/g" \
            -e "s/@a1mod_version@/${a1mod_v}/g" \
            -e "s/@a1pm_version@/${a1pm_v}/g" \
            -e "s/@a1gui_version@/${gui_v}/g" \
            -e "s/@general_version@/${general_v}/g" \
            "${cxxa1_src_path}/a1/core/version.hpp.in" > "${cxxa1_src_path}/a1/core/version.hpp"

        sed -e "s/@version@/${gui_v}/g" \
            "${src_path}/gui/Info.plist.in" > "${src_path}/gui/Info.plist"

        echo "a1_version=${a1_v}"
        echo "a1ctl_version=${a1ctl_v}"
        echo "a1mod_version=${a1mod_v}"
        echo "a1pm_version=${a1pm_v}"
        echo "gui_version=${gui_v}"
        echo "general_version=${general_v}"
    }

    local targets=()
    local arg
    for arg in "$@"
    do
        case "$arg" in
            all|"") targets=(a1 a1ctl a1mod a1pm gui general) ;;
            a1|a1ctl|a1mod|a1pm|gui|general) targets+=("$arg") ;;
            --no-*) ;;
            *) echo "[Error]: unsupported parameter: $arg" >&2; return 1 ;;
        esac
    done
    [[ ${#targets[@]} -eq 0 ]] && targets=(a1 a1ctl a1mod a1pm gui general)

    local t new_ver
    for t in "${targets[@]}"
    do
        new_ver="$(_bump "$t")" || return 1
        _write_version_ini "$t" "$new_ver"
        _retag "$t" "$new_ver"
    done

    _render_headers
}

get_version() {
    local script_path="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"
    _read_ini() {
        local key="$1"
        local ini="${script_path}/../version.ini"
        [[ -f "$ini" ]] || return 1
        local line
        line="$(grep -E "^${key}[[:space:]]*=" "$ini" 2>/dev/null | head -n1)" || return 1
        [[ -z "$line" ]] && return 1
        local val="${line#*=}"
        val="$(echo "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
            -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
        printf '%s' "$val"
    }

    _from_git() {
        local name="$1"
        local tag
        tag="$(git tag -l "${name}-v*" --sort=-v:refname | head -n1)"
        [[ -z "$tag" ]] && return 1
        local ver="${tag#*-v}"
        local major minor patch build
        IFS='.' read -r major minor patch build <<< "$ver"
        local cnt
        cnt="$(git rev-list --count "${tag}..HEAD" 2>/dev/null || echo 0)"
        printf '%s.%s.%s.%s' "$major" "$minor" "$patch" "$((build + cnt))"
    }

    local key="$1"
    case "$key" in
        "") echo "[Error]: need options" >&2; exit 1 ;;
        a1|a1ctl|a1mod|a1pm|gui|general) ;;
        a1gui) key="gui" ;;
        *) echo "[Error]: unsupported parameters: $1" >&2; exit 1 ;;
    esac

    local v
    v="$(_from_git "$key")" && { printf '%s' "$v"; return 0; }
    v="$(_read_ini "${key}_version")" && { printf '%s' "$v"; return 0; }
    echo "[Error]: cannot resolve version for ${key}" >&2
    exit 1
}
