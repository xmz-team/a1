#generate-version.sh
generate_version() {
local script_path="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"

source "${script_path}/env.sh"

a1_version=""
a1ctl_version=""
a1mod_version=""
a1pm_version=""
temp_file=$(mktemp)

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
       [[ "$line" =~ ^(a1_version|a1ctl_version|a1mod_version|a1pm_version)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        should_update=0
        case "$1" in
            a1)      [[ "$key" == "a1_version" ]] && should_update=1 ;;
            a1ctl)   [[ "$key" == "a1ctl_version" ]] && should_update=1 ;;
            a1mod)   [[ "$key" == "a1mod_version" ]] && should_update=1 ;;
            a1pm)    [[ "$key" == "a1pm_version" ]] && should_update=1 ;;
            all|"")  should_update=1 ;;
        esac
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
        esac
    else
        echo "$line" >> "$temp_file"
    fi
done < "${script_path}/../version.ini"

mv "$temp_file" "${script_path}/../version.ini"

if [ -z "$a1_version" ] || [ -z "$a1ctl_version" ] || [ -z "$a1mod_version" ] || [ -z "$a1pm_version" ]; then
    while IFS='=' read -r key value
    do
        key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')
        case "$key" in
            a1_version) a1_version="$value" ;;
            a1ctl_version) a1ctl_version="$value" ;;
            a1mod_version) a1mod_version="$value" ;;
            a1pm_version) a1pm_version="$value" ;;
        esac
    done < <(grep -E "^(a1_version|a1ctl_version|a1mod_version|a1pm_version)=" "${script_path}/../version.ini")
fi

echo "a1_version=$a1_version"
echo "a1ctl_version=$a1ctl_version"
echo "a1mod_version=$a1mod_version"
echo "a1pm_version=$a1pm_version"

sed -e "s/@a1_version@/$a1_version/g" \
    -e "s/@a1ctl_version@/$a1ctl_version/g" \
    -e "s/@a1mod_version@/$a1mod_version/g" \
    -e "s/@a1pm_version@/$a1pm_version/g" \
    "${src_path}/a1/core/version.hpp.in" > "${src_path}/a1/core/version.hpp"
}
