#!/usr/bin/env bash
declare -A vars
vars[ingest]="ingest"
vars[cwd]="$PWD"
# Vars ^ #
initColors() {
    bred='\033[1;31m'
    bgrn='\033[1;32m'
    bblu='\033[1;34m'
    red='\033[0;31m'
    grn='\033[0;32m'
    yel='\033[0;33m'
    blu='\033[0;34m'
    rst='\033[0m'
}
# COLORS ^ #
Banner () {
    initColors
    echo -e "${bred}"
    cat << "EOF"
______ _                 ___   _______  ___   _____ _   _
| ___ \ |               | \ \ / / ___ \/ _ \ /  ___| | | |
| |_/ / | ___   ___   __| |\ V /| |_/ / /_\ \\ `--.| |_| |
| ___ \ |/ _ \ / _ \ / _` | \ / | ___ \  _  | `--. \  _  |
| |_/ / | (_) | (_) | (_| | | | | |_/ / | | |/\__/ / | | |
\____/|_|\___/ \___/ \__,_| \_/ \____/\_| |_/\____/\_| |_/  v0.0
        By @theRealHacker
EOF
    echo -e "${rst}"
}
Menu() {
    initColors
    Banner
    echo -e "${bblu}[*]${rst} Welcome to ${red}BloodyBASH${rst}"
    echo -e "${bblu}[i]${rst} Set"
    echo -e "${bblu}[i]${rst} findUsers"
    echo -e "${bblu}[i]${rst} JQ"
    return 0
}
Set () {
    initColors
    SetRunCWD() {
        if [[ -d "${vars[cwd]}" ]]; then
            cd "${vars[cwd]}" || return 1
        else
            echo -e "${red}[!]${rst} ${vars[cwd]} is not a directory."
            return 1
        fi
    }
    SetRunINGEST() {
        if [[ ! -d "${vars[ingest]}" ]]; then
            echo -e "${red}[!]${rst} ${vars[ingest]} is not a directory."
            return 1
        fi
    }
    local varname="$1"
    shift
    local value="$*"
    if [[ "$varname" == "ALL" ]]; then
        for i in "${!vars[@]}"; do
            echo -e "${bblu}[i]${rst} ${i} => ${vars[$i]:-<unset>}"
        done
        return 0
    fi
    [[ -z "$varname" ]] && return 1
    if [[ -z "$value" ]]; then
        echo -e "${bblu}[i]${rst} ${varname} => ${vars[$varname]:-<unset>}"
        return 0
    fi
    # Expand relative paths like ~ or ..
    if [[ "$value" =~ ^(\.|\.\.|~) ]]; then
        value="$(realpath -m "$value" 2>/dev/null)"
    fi
    vars["$varname"]="$value"
    echo -e "${bgrn}[+]${rst} ${varname} => ${vars[$varname]}"
    [[ "$varname" == "ingest" ]] && SetRunINGEST
    [[ "$varname" == "cwd" ]] && SetRunCWD
}
findUsers() {
    local query="$1"
    local pattern=${query//\*/.*}
    if ! userData >/dev/null; then return 1; fi # Tried to not make it run twice
    userData | jq -r --arg pattern "$pattern" '
        .data[]
        | select(.Properties.name | test($pattern))
        | .Properties.name' | {
            found=0
            while read -r match; do
                [[ -n "$match" ]] && { echo -e "${bgrn}[+]${rst} $match"; found=1; }
            done
            if [[ $found -eq 0 ]]; then
                echo -e "${red}[!]${rst} No matches found for pattern: $query"
            fi
        }
    return 0
}
JQ() {
    local jqCMD="$@"
    JQuserWrap() {
        [[ "$jqCMD" =~ ^users ]] && u=true && jqCMD=$(echo "$jqCMD" | sed 's/^users\././g')
        if [ "$u" = true ]; then
            userData | jq "$jqCMD" 2>/dev/null
        fi
    }
    JQuserWrap
}
JQ() { # will add more options later
    local jqCMD="$@"
    [[ "$jqCMD" =~ ^users ]] && u=true; jqCMD=$(echo "$jqCMD" | sed 's|users\.|.[].|g')
    if [ "$u" = true ]; then
        userData | jq "$jqCMD" 2>/dev/null
    fi
}
# MODULES ^ #
Help() {
    initColors
    case "$1" in
        Menu)
            echo -e "${bblu}[Help]${rst} Menu — shows the main menu with available modules";;
        Set)
            echo -e "${bblu}[Help]${rst} Set <key> <value> — sets a variable like 'cwd' or 'ingest'"
            echo -e "${bblu}[Help]${rst} Set ALL — shows all variables currently set";;
        findUsers)
            echo -e "${bblu}[Help]${rst} findUsers <pattern> — searches users matching wildcard (e.g., 'ADMIN*')"
            ;;
        JQ)
            echo -e "${bblu}[Help]${rst} JQ <jq expression> — runs jq on data, (e.g., 'users.data[].Properties.name')"
            echo -e "${bblu}[Help]${rst} Use 'users.' prefix to target user data, (e.g., 'users.data[] | select(.Properties.name == \"John\")')"
            ;;
        listUsers)
            echo -e "${bblu}[Help]${rst} listUsers — lists all user names"
            ;;
        listUserKeys)
            echo -e "${bblu}[Help]${rst} listUserKeys — lists JSON keys in user files"
            ;;
        listUserValues)
            echo -e "${bblu}[Help]${rst} listUserValues — lists values for each user JSON entry"
            ;;
        JQ)
            echo -e "${bblu}[Help]${rst} JQ <jq filter> — runs jq on user data"
            echo -e "${bblu}[Help]${rst} JQ user.<filter> — runs jq on user data (e.g., user.Properties.name)";;
        *)

            echo -e "${bblu}[Help]${rst} Available commands: Menu, listUsers, listUserKeys, listUserValues"
            echo -e "${bblu}[Help]${rst} Try: Help <command|module>";;
    esac
    return 0
}
userData() {
    if ! ls "${vars[ingest]}"/*users.json &>/dev/null; then
        echo -e "${red}[!]${rst} No user JSON files found in ${vars[ingest]} directory." >&2
        echo -e "${bblu}[i]${rst} Current ingest path: ${vars[ingest]}"
        return 1
    fi
    jq -s 'flatten' "${vars[ingest]}"/*users.json | jq .[]
}
listUsers() {
    userData | jq '.data[].Properties.name'
}
listUserKeys() {
    userData | jq 'keys'
}
listUserValues() {
    userData | jq 'values'
}
# MAIN FUNCTIONS ^ #
MAIN() {
    initColors
    trap 'echo -e "\n${blu}[*]${rst} Exiting..."; exit 0' SIGINT
    HISTFILE=~/.bloodybash_history
    HISTSIZE=1000
    while true; do
        history -r "$HISTFILE"
        ccwd=$(pwd|sed "s|$HOME|~|g")
        read -re -p "$(printf '\033[0;31m**BloodyBASH**\033[0m [\033[1;33m%s\033[0m]\033[0m >>> ' "$ccwd")" input
        [[ -n "$input" ]] && echo "$input" >> "$HISTFILE"
        case $input in
            "exit"|"dd") echo -e "${blu}[*]${rst} Exiting..."; exit 0;;
            "clear"|"cc") clear;;
            "Help "*|"help "*|Help|help) Help "${input#Help }";;
            # Split
            Menu|menu) Menu;;
            "Set "*|"set "*) args=($input); unset args[0]; Set "${args[@]}";;
            "JQ "*) JQ "${input#JQ }";;
            "findUsers "*) findUsers "${input#findUsers }";;
            # Split
            "listUsers") listUsers;;
            "listUserKeys") listUserKeys;;
            "listUserValues") listUserValues;;
            *) if [ -n "$input" ];then bash -c "$input" 2>/dev/null;fi;;
        esac
    done
}
# MAIN ^ #
MAIN # Wrapping the script in a function for some reason
