#!/bin/bash
# ttytok watcher — tail a temp file in a tmux pane

TYPE=$1
RESTART="RESTART_SCREEN_TT"

banner() {
    local color=$1 label=$2
    printf "${color}--- %s ---\033[0m\n" "$label"
}

case "$TYPE" in
    chats)
        FILE="/tmp/ttytok_chats"
        touch "$FILE"
        banner '\033[36;1m' 'CHAT'
        tail -n0 -f "$FILE" 2>/dev/null | while IFS= read -r line; do
            if [[ "$line" == *"$RESTART"* ]]; then
                clear; banner '\033[36;1m' 'CHAT'
                truncate -s 0 "$FILE"
            else
                echo "$line"
            fi
        done
        ;;
    gifts)
        FILE="/tmp/ttytok_gifts"
        touch "$FILE"
        banner '\033[33;1m' 'GIFTS'
        tail -n0 -f "$FILE" 2>/dev/null | while IFS= read -r line; do
            if [[ "$line" == *"$RESTART"* ]]; then
                clear; banner '\033[33;1m' 'GIFTS'
                truncate -s 0 "$FILE"
            else
                printf '\033[33m>\033[0m %s\n' "$line"
            fi
        done
        ;;
    joins)
        FILE="/tmp/ttytok_joins"
        touch "$FILE"
        banner '\033[32;1m' 'ACTIVITY'
        tail -n0 -f "$FILE" 2>/dev/null | while IFS= read -r line; do
            if [[ "$line" == *"$RESTART"* ]]; then
                clear; banner '\033[32;1m' 'ACTIVITY'
                truncate -s 0 "$FILE"
            else
                printf '\033[32m>\033[0m %s\n' "$line"
            fi
        done
        ;;
    mpv)
        FILE="/tmp/ttytok_mpv"
        touch "$FILE"
        echo "waiting for stream..."
        tail -n0 -f "$FILE" 2>/dev/null | while IFS= read -r line; do
            [[ -n "$MPV_PID" ]] && kill "$MPV_PID" 2>/dev/null && wait "$MPV_PID" 2>/dev/null
            MPV_PID=""
            if [[ "$line" == "AGE_RESTRICTED" ]]; then
                clear
                banner '\033[33;1m' 'AGE RESTRICTED'
                echo "video unavailable without cookies"
                echo "chat/gifts/joins still work"
            elif [[ "$line" == "SWITCH" ]]; then
                clear
                echo "switching..."
            elif [[ "$line" =~ ^https?:// ]]; then
                clear
                if command -v mpv &>/dev/null; then
                    mpv --vo=tct --really-quiet -- "$line" &
                    MPV_PID=$!
                else
                    echo "stream: $line"
                    echo "(install mpv for video)"
                fi
            fi
        done
        ;;
    *)
        echo "usage: watchers.sh <chats|gifts|joins|mpv>"
        exit 1
        ;;
esac
