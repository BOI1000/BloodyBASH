#!/usr/bin/env bash
# Vars
declare -A vars
vars[ingest]="ingest"
vars[cwd]="$PWD"

# Load Config
loadConfig() {
    local config_file="${HOME}/.bloodybashrc"
    if [ -f "$config_file" ]; then
        source "$config_file"
        vars[cwd]="${CWD:-$PWD}"
        vars[ingest]="${INGEST:-ingest}"
    fi
}
# Create config
createConfig() {
    echo -ne "${bblu}[?]${rst} No config found. Create one? (Y/n)"
    read -srn1 resp
    if [[ "$resp" =~ ^[Yy]?$ ]]; then
        cat > "${HOME}/.bloodybash.rc" <<EOF
# BloodyBASH configuration file
CWD="$PWD"
INGEST="ingest"
EOF
        echo -e "${bgrn}[+]${rst} Config created at ~/.bloodybashrc"
    fi
}

initColors() {
    bred='\033[1;31m'
    bgrn='\033[1;32m'
    bblu='\033[1;34m'
    red='\033[0;31m'
    grn='\033[0;32m'
    yel='\033[1;33m'
    blu='\033[0;34m'
    rst='\033[0m'
}

# Spinner function
progress_Spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    printf " "
    while kill -0 $pid 2>/dev/null; do
        for c in / - \\ \|; do
            printf "\b%c" "%c"
            sleep $delay
        done
    done
    printf "\b \n"
}
# Banner
Banner () {
    initColors
    echo -ne "${red}"
    cat << "EOF"
______ _                 ___   _______  ___   _____ _   _
| ___ \ |               | \ \ / / ___ \/ _ \ /  ___| | | |
| |_/ / | ___   ___   __| |\ V /| |_/ / /_\ \\ `--.| |_| |
| ___ \ |/ _ \ / _ \ / _` | \ / | ___ \  _  | `--. \  _  |
| |_/ / | (_) | (_) | (_| | | | | |_/ / | | |/\__/ / | | |
\____/|_|\___/ \___/ \__,_| \_/ \____/\_| |_/\____/\_| |_/
EOF
    echo -e "${rst}\t\tby @${red}theRealHacker${rst}\tv0.1\n"
}
ShowStatus() {
    local usercount=$(find "${vars[ingest]}" -type f -name '*users.json' 2>/dev/null | wc -l)
    [ -n $usercount ] && echo -e "${grn}[+]${rst} User json files detected: $count"
}
# Menu
Menu() {
    initColors
    Banner
    echo -e "${bred}[*]${rst} Welcome to ${red}BloodyBASH${rst}"
    echo -e "${bblu}[i]${rst} Set"
    echo -e "${bblu}[i]${rst} findUsers"
    echo -e "${bblu}[i]${rst} findUsersAdvanced"
    echo -e "${bblu}[i]${rst} JQ"
    echo -e "${bblu}[i]${rst} Help"
    return 0
}
# Input Validation && Error Handling
initDeps() {
    local missing=0
    for dep in jq realpath; do
        command -v "$dep" >/dev/null 2>&1 || \
            { echo -e "${red}[!]${rst} Missing Dependency: $dep"; missing=1; }
    done
    return $missing
}
initJSONV() {
    local valid=1
    for f in "${vars[ingest]}"/*users.json; do
        jq empty "$f" 2>/dev/null || {
            echo -e "${red}[!]${rst} Invalid JSON file: $f"; valid=0
        }
    done
    return $valid
}
initEnsureDirs() {
    [[ -d "${vars[ingest]}" ]] || { echo -e "${yel}[!]${rst} Creating missing ingest dir: ${vars[ingest]}"; mkdir -p "${vars[ingest]}"; }
    [[ -d "${vars[cwd]}" ]] || { echo -e "${yel}[!]${rst} Creating missing current working directory: ${vars[cwd]}"; mkdir -p "${vars[cwd]}"; }
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
        [[ -d "${vars[ingest]}" ]] || { echo -e "${red}[!]${rst} ${vars[ingest]} is not a directory."; return 1; }
    }
    local varname="$1";shift;local value="$*"
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

# User Data Operations
getUserData() {
    if ! ls "${vars[ingest]}"/*users.json &>/dev/null; then
        echo -e "${red}[!]${rst} No user JSON files found in ${vars[ingest]} directory." >&2
        echo -e "${bblu}[i]${rst} Current ingest path: ${vars[ingest]}"
        return 1
    fi
    jq -s 'flatten' "${vars[ingest]}"/*users.json | jq .[]
}
listUsers() {
    getUserData | jq .data[].Properties.name
}
listUserKeys() {
    getUserData | jq 'keys'
}
listUserValues(){
    getUserData | jq 'values'
}

# Advnaced Search && Filtering
findUsers() {
    local query="$1"
    local pattern=${query//\*/.*}
    if ! getUserData >/dev/null; then return 1; fi # Tried to not make it run twice
    getUserData | jq -r --arg pattern "$pattern" '
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
findUsersAdvanced() {
    local query="$1"
    local prop="${2:-Properties.name}"
    prop="${prop#.}"
    if ! getUserData >/dev/null; then return 1; fi
    getUserData | jq -r --arg pattern "$query" --arg prop "$prop" '
    .data[] | select(getpath(($prop | split("."))) | tostring | test($pattern)) | getpath(($prop | split(".")))
    ' | {
        found=0
        while read -r match; do
            [[ -n "$match" ]] && { echo -e "${bgrn}[+]${rst} $match"; found=1; }
        done
        [[ "$found" -eq 0 ]] && echo -e "${red}[!]${rst} No matches found for $prop ~ $query"
    }
}
JQ() {
    local jqCMD="$@"
    JQuserWrap() {
        [[ "$jqCMD" =~ ^users ]] && u=true && jqCMD=$(echo "$jqCMD" | sed 's/^users\././g')
        if [ "$u" = true ]; then
            getUserData | jq "$jqCMD" 2>/dev/null
        fi
    }
    JQuserWrap
}
JQ() {
    local jqCMD="$@"
    [[ "$jqCMD" =~ ^users ]] && u=true; jqCMD=$(echo "$jqCMD" | sed 's/users\./\./g')
    if [ "$u" = true ]; then
        getUserData | jq "$jqCMD" 2>/dev/null
    fi
}
# Help && Docs
Help() {
    initColors
    case "$1" in
        Menu)
            echo -e "${bblu}[Help]${rst} Menu — shows the main menu with available modules"
            ;;
        Set)
            echo -e "${bblu}[Help]${rst} Set <key> <value> — sets a variable like 'cwd' or 'ingest'"
            echo -e "${bblu}[Help]${rst} Set ALL — shows all variables currently set";;
        findUsers)
            echo -e "${bblu}[Help]${rst} findUsers <pattern> — searches users matching wildcard (e.g., 'ADMIN*')"
            ;;
        findUsersAdvanced)
            echo -e "${bblu}[Help]${rst} findUsersAdvanced <regex> <property> — advanced search (e.g., '^A.*' '.Properties.email')"
            ;;
        JQ)
            echo -e "${bblu}[Help]${rst} JQ <jq expression> — runs jq on data, (e.g., 'users.data[].Properties.name')"
            echo -e "${bblu}[Help]${rst} Use 'users.' prefix to target user data, (e.g., 'users.data[] | select(.Properties.name == \"John\")')";;
        listUsers)
            echo -e "${bblu}[Help]${rst} listUsers — lists all user names"
            ;;
        listUserKeys)
            echo -e "${bblu}[Help]${rst} listUserKeys — lists JSON keys in user files"
            ;;
        listUserValues)
            echo -e "${bblu}[Help]${rst} listUserValues — lists values for each user JSON entry"
            ;;
        *)
            echo -e "${bblu}[Help]${rst} Available commands: Menu, listUsers, listUserKeys, listUserValues"
            echo -e "${bblu}[Help]${rst} Try: Help <command|module>";;
    esac
    return 0
}
# MAIN Loop
MAIN() {
    # Initialization
    initColors
    loadConfig
    initEnsureDirs
    initDeps || { echo -e "${red}[!]${rst} Returned dependencies missing. Exiting."; exit 1; }
    initJSONV || echo -e "${yel}[!]${rst} Some JSON files are invalid. Proceed with caution."
    trap 'echo -e "\n${blu}[*]${rst} Exiting..."; exit 0' SIGINT
    HISTFILE=~/.bloodybash_history
    HISTSIZE=1000
    while true; do
        history -r "$HISTFILE"
        ccwd=$(pwd|sed "s|$HOME|~|g")
        read -re -p "$(printf '\033[0;31m**BloodyBASH**\033[0m [\033[1;33m%s\033[0m]\033[0m>> ' "$ccwd")" input
        [[ -n "$input" ]] && echo "$input" >> "$HISTFILE"
        case $input in
            "exit"|"dd") echo -e "${blu}[*]${rst} Exiting..."; exit 0;;
            "clear"|"cc") clear;;
            "Help "*|"help "*|Help|help) Help "${input#Help }";;
            "Menu"|"menu") Menu;;
            "Set "*|"set "*) args=($input); unset args[0]; Set "${args[@]}";;
            "findUsers "* ) findUsers "${input#findUsers }";;
            "findUsersAdvanced "* ) findUsersAdvanced $(echo "${input#findUsersAdvanced }");;
            "JQ "* ) JQ "${input#JQ }";;
            "listUsers") listUsers;;
            "listUserKeys") listUserKeys;;
            "listUserValues") listUserValues;;
            "createConfig") createConfig;;
            *) if [ -n "$input" ]; then bash -c "$input" 2>/dev/null; fi;;
        esac
    done
}
MAIN
