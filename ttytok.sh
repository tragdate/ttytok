#!/bin/bash
# ttytok — TikTok Live TUI client
# Pure shell, no signing server, no Rust binary
# Dependencies: bash, tmux, fzf, openssl

USERS_FILE="$HOME/.local/share/ttytok/users"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# resolve installed vs local script paths
if [[ -d "$HOME/.local/lib/ttytok" ]]; then
    LIB_DIR="$HOME/.local/lib/ttytok"
elif [[ -d "/usr/local/lib/ttytok" ]]; then
    LIB_DIR="/usr/local/lib/ttytok"
else
    LIB_DIR="$SCRIPT_DIR"
fi

# source piratetok library if available
for _pt_path in \
    "$LIB_DIR/lib/piratetok.sh" \
    "$HOME/.local/lib/piratetok/piratetok.sh" \
    "/usr/local/lib/piratetok/piratetok.sh" \
    "$SCRIPT_DIR/../../live-sh/lib/piratetok.sh"
do
    if [[ -f "$_pt_path" ]]; then
        . "$_pt_path"
        break
    fi
done

mkdir -p "$(dirname "$USERS_FILE")"
touch "$USERS_FILE"

# --- CLI commands ---
case "${1:-}" in
    add)
        [[ -z "$2" ]] && { echo "usage: ttytok add <username>"; exit 1; }
        user="${2#@}"
        if grep -qx "$user" "$USERS_FILE" 2>/dev/null; then
            echo "$user already in list"
        else
            echo "$user" >> "$USERS_FILE"
            echo "added $user"
        fi
        exit
        ;;
    remove|rm)
        [[ -z "$2" ]] && { echo "usage: ttytok remove <username>"; exit 1; }
        user="${2#@}"
        sed -i "/^${user}$/d" "$USERS_FILE"
        echo "removed $user"
        exit
        ;;
    list|ls)
        cat "$USERS_FILE"
        exit
        ;;
    discover)
        echo "fetching live feed..."
        bash "$LIB_DIR/discover.sh" | while IFS=$'\t' read -r user viewers title; do
            printf '\033[32m● %-20s\033[0m %6s viewers  %s\n' "$user" "$viewers" "$title"
        done
        exit
        ;;
    check)
        [[ -z "$2" ]] && { echo "usage: ttytok check <username>"; exit 1; }
        user="${2#@}"
        if [[ -n "$_PT_SOURCED" ]]; then
            result=$(pt_check_online "$user")
            case "$result" in
                LIVE:*) printf '\033[32m● %s is LIVE\033[0m (room %s)\n' "$user" "${result#LIVE:}" ;;
                404)    printf '\033[31m✕ %s not found\033[0m\n' "$user" ;;
                *)      printf '\033[90m○ %s is offline\033[0m\n' "$user" ;;
            esac
        else
            echo "piratetok.sh library not found — install piratetok-live-sh" >&2
            exit 1
        fi
        exit
        ;;
    help|-h|--help)
        cat <<'HELP'
ttytok — TikTok Live TUI

usage:
  ttytok                    open TUI (tmux + fzf)
  ttytok add <user>         add user to watch list
  ttytok remove <user>      remove user from watch list
  ttytok list               list saved users
  ttytok discover           browse live users from TikTok feed
  ttytok check <user>       check if a specific user is live

TUI keybindings:
  enter    connect to selected user
  ^d       discover live users (feed browse)
  ^r       refresh saved users' online status
  ^a       add a new user
  ^x       remove selected user
HELP
        exit
        ;;
esac

# --- check deps ---
for dep in tmux fzf openssl gzip; do
    command -v "$dep" &>/dev/null || { echo "missing: $dep"; exit 1; }
done

# --- create temp files ---
for f in /tmp/ttytok_{chats,gifts,joins,mpv,status,viewers}; do
    touch "$f"
    truncate -s 0 "$f"
done

# --- tmux layout ---
SESSION="ttytok"

# kill existing session
tmux kill-session -t "$SESSION" 2>/dev/null

tmux new-session -d -s "$SESSION" "bash '${LIB_DIR}/watchers.sh' mpv"
tmux splitw -h -l 75%      "bash '${LIB_DIR}/watchers.sh' joins"
tmux splitw -v -l 95% -t 1 "bash '${LIB_DIR}/watchers.sh' gifts"
tmux splitw -v -l 93% -t 2 "bash '${LIB_DIR}/watchers.sh' chats"
tmux splitw -v -l 12% -t 3 "bash '${LIB_DIR}/userselect.sh'"
tmux select-pane -t 4

# ctrl-q kills the whole session
tmux bind-key -T root C-q kill-session -t "$SESSION"

tmux attach -t "$SESSION"
