#!/usr/bin/env bash
while [ "$#" -gt 0 ]; do
    case "$1" in
        --help|-h) echo "Usage: $0 [--ingest <file>]"; exit 0;;
        --ingest) ingestFile="$2";shift 2;;
        -r) r=true;shift;;
        -sv) sv=true;shift;;
        ?*) exit 1;;
        *) echo "Usage: $0 [--ingest <file>]"; exit 1;;
    esac
done; [ ! -f "$ingestFile" ] && echo "Usage: $0 [--ingest <file>]" && exit 1
Ingest() { local file="$ingestFile";cat "$file"; }
initJQ() {
    local in="$@"
    [ "$r" = true ] && Ingest | jq -r "$in" 2>/dev/null || {
        Ingest | jq "$in" 2>/dev/null
    }
}
MAIN() {
    HISTFILE=/tmp/.jqsh_history;HISTSIZE=1000;touch "$HISTFILE"
    while true; do
        history -r
        read -re -p "JQ> " input
        [ -n "$input" ] && echo "$input" >> "$HISTFILE" && initJQ "$input"
        [ "$input" = "exit" ] && [ "$sv" != true ] && rm /tmp/.jqsh_history && break || [ "$input" = "exit" ] && break
    done
}
MAIN