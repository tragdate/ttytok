#!/bin/bash
# ttytok user selector — fzf-based user picker with discover + status

USERS_FILE="$HOME/.local/share/ttytok/users"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONNECTOR="$SCRIPT_DIR/connector.sh"
DISCOVER="$SCRIPT_DIR/discover.sh"
STATUS_CACHE="/tmp/ttytok_discover_cache"

# source piratetok library for check_online
for _pt_path in \
    "$SCRIPT_DIR/lib/piratetok.sh" \
    "$HOME/.local/lib/piratetok/piratetok.sh" \
    "/usr/local/lib/piratetok/piratetok.sh" \
    "$SCRIPT_DIR/../../live-sh/lib/piratetok.sh"
do
    if [[ -f "$_pt_path" ]]; then
        . "$_pt_path"
        break
    fi
done

cleanup() {
    pkill -f "connector.sh" 2>/dev/null
    rm -f /tmp/ttytok_chats /tmp/ttytok_gifts /tmp/ttytok_joins /tmp/ttytok_status
}
trap cleanup EXIT SIGHUP SIGINT SIGTERM

mkdir -p "$(dirname "$USERS_FILE")"
touch "$USERS_FILE"

check_user() {
    local user=$1
    if [[ -n "$_PT_SOURCED" ]]; then
        PT_UA=$(pt_random_ua)
        local result
        result=$(pt_check_online "$user")
        case "$result" in
            LIVE:*) echo "LIVE" ;;
            404)    echo "404" ;;
            *)      echo "OFF" ;;
        esac
    else
        # fallback: inline HTTP check
        local ua="Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"
        local path="/api-live/user/room?aid=1988&app_name=tiktok_web&device_platform=web_pc&app_language=en&browser_language=en-US&user_is_login=false&sourceType=54&uniqueId=${user}"
        local resp
        resp=$({
            printf 'GET %s HTTP/1.0\r\n' "$path"
            printf 'Host: www.tiktok.com\r\n'
            printf 'User-Agent: %s\r\n' "$ua"
            printf 'Accept: */*\r\n'
            printf 'Accept-Encoding: identity\r\n'
            printf '\r\n'
        } | openssl s_client -connect "www.tiktok.com:443" -quiet 2>/dev/null)
        local sc rid lstatus
        sc=$(echo "$resp" | grep -o '"statusCode":[0-9]*' | head -1 | sed 's/.*://')
        rid=$(echo "$resp" | grep -o '"roomId":"[0-9]*' | head -1 | sed 's/.*"//')
        lstatus=$(echo "$resp" | grep -o '"status":2' | head -1)
        if [[ "$sc" == "0" && -n "$rid" && "$rid" != "0" && -n "$lstatus" ]]; then
            echo "LIVE"
        elif [[ "$sc" == "19881007" ]]; then
            echo "404"
        else
            echo "OFF"
        fi
    fi
}

refresh_status() {
    > "$STATUS_CACHE"
    printf '\033[90mchecking users...\033[0m\r' >/dev/tty
    while IFS= read -r user; do
        [[ -z "$user" ]] && continue
        user="${user#@}"
        ( printf '%s\t%s\n' "$user" "$(check_user "$user")" >> "$STATUS_CACHE" ) &
    done < "$USERS_FILE"
    wait
    printf '\033[2K\r' >/dev/tty
}

build_list() {
    while IFS= read -r user; do
        [[ -z "$user" ]] && continue
        local status="?"
        if [[ -f "$STATUS_CACHE" ]]; then
            local cached
            cached=$(grep "^${user}	" "$STATUS_CACHE" 2>/dev/null | cut -f2)
            [[ -n "$cached" ]] && status="$cached"
        fi
        case "$status" in
            LIVE) printf '\033[32m● %s [LIVE]\033[0m\n' "$user" ;;
            404)  printf '\033[31m✕ %s [NOT FOUND]\033[0m\n' "$user" ;;
            OFF)  printf '\033[90m○ %s\033[0m\n' "$user" ;;
            *)    printf '  %s\n' "$user" ;;
        esac
    done < "$USERS_FILE"
}

parse_user() {
    echo "$1" | sed 's/\x1b\[[0-9;]*m//g;s/^[●○✕ ]* //;s/ \[.*$//'
}

do_connect() {
    local user
    user=$(parse_user "$1")
    [[ -z "$user" ]] && return

    pkill -f "connector.sh" 2>/dev/null
    echo "SWITCH" >> /tmp/ttytok_mpv
    sleep 0.1

    for f in /tmp/ttytok_chats /tmp/ttytok_gifts /tmp/ttytok_joins; do
        echo "RESTART_SCREEN_TT" >> "$f" 2>/dev/null
    done
    truncate -s 0 /tmp/ttytok_status 2>/dev/null

    bash "$CONNECTOR" "$user" > /dev/null 2>&1 &
}

DISC_CATS="recommended suggested popular trending chatting fashion lifestyle outdoor gaming minecraft fortnite valorant"

format_feed() {
    echo "$1" | while IFS=$'\t' read -r user viewers title; do
        [[ -z "$user" ]] && continue
        if grep -qx "$user" "$USERS_FILE" 2>/dev/null; then
            printf '\033[32m★ %-20s \033[33m%6s\033[32m  %s\033[0m\n' "$user" "$viewers" "$title"
        else
            printf '  %-20s \033[33m%6s\033[0m  %s\n' "$user" "$viewers" "$title"
        fi
    done
}

fetch_discover() {
    local cat=${1:-}
    printf '\033[90mfetching %s...\033[0m\r' "${cat:-live feed}" >/dev/tty
    bash "$DISCOVER" "$cat" 2>/dev/null
    printf '\033[2K\r' >/dev/tty
}

pick_category() {
    echo "$DISC_CATS" | tr ' ' '\n' | fzf \
        --header="pick category (esc=random)" \
        --layout=reverse
}

do_discover() {
    local cat="" feed
    feed=$(fetch_discover)

    while true; do
        if [[ -z "$feed" ]]; then
            printf '\033[31mno results (blocked or empty)\033[0m\n' >/dev/tty
            sleep 1.5
            return
        fi

        local formatted
        formatted=$(format_feed "$feed")
        [[ -z "$formatted" ]] && return

        local picked
        picked=$(echo "$formatted" | fzf \
            --ansi \
            --multi \
            --header="enter:add+connect | ^a:add | ^r:refresh | ^t:category [${cat:-random}]" \
            --layout=reverse \
            --expect="ctrl-a,ctrl-r,ctrl-t")

        local dkey
        dkey=$(echo "$picked" | head -1)

        case "$dkey" in
            ctrl-r)
                feed=$(fetch_discover "$cat")
                continue
                ;;
            ctrl-t)
                cat=$(pick_category)
                feed=$(fetch_discover "$cat")
                continue
                ;;
        esac

        local selections
        selections=$(echo "$picked" | tail -n +2)
        [[ -z "$selections" ]] && return

        local first_user=""
        while IFS= read -r line; do
            local clean_user
            clean_user=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g;s/^[★ ]*//' | awk '{print $1}')
            [[ -z "$clean_user" ]] && continue
            if ! grep -qx "$clean_user" "$USERS_FILE" 2>/dev/null; then
                echo "$clean_user" >> "$USERS_FILE"
            fi
            [[ -z "$first_user" ]] && first_user="$clean_user"
        done <<< "$selections"

        if [[ "$dkey" != "ctrl-a" && -n "$first_user" ]]; then
            do_connect "$first_user"
        fi
        return
    done
}

while true; do
    result=$(build_list | fzf \
        --ansi \
        --header="enter:connect | ^d:discover | ^r:refresh | ^a:add | ^x:remove" \
        --no-sort \
        --layout=reverse \
        --expect="ctrl-a,ctrl-x,ctrl-d,ctrl-r")

    key=$(echo "$result" | head -1)
    choice=$(echo "$result" | sed -n '2p')

    case "$key" in
        ctrl-d)
            do_discover
            ;;
        ctrl-r)
            refresh_status
            ;;
        ctrl-a)
            read -rp "add username: " new_user < /dev/tty
            new_user="${new_user#@}"
            if [[ -n "$new_user" ]]; then
                if grep -qx "$new_user" "$USERS_FILE" 2>/dev/null; then
                    printf '%s already in list\n' "$new_user"
                    sleep 1
                else
                    echo "$new_user" >> "$USERS_FILE"
                fi
            fi
            ;;
        ctrl-x)
            rm_user=$(parse_user "$choice")
            [[ -n "$rm_user" ]] && sed -i "/^${rm_user}$/d" "$USERS_FILE"
            ;;
        *)
            [[ -n "$choice" ]] && do_connect "$choice"
            ;;
    esac

    sleep 0.3
done
