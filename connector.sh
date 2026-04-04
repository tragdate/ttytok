#!/bin/bash
# ttytok connector — TikTok Live event stream to temp files
# Sources piratetok.sh library, writes events to /tmp/ttytok_*
set +e

USERNAME="${1:?usage: connector.sh <username>}"
USERNAME="${USERNAME#@}"

# --- paths ---
CHAT_FILE="/tmp/ttytok_chats"
GIFT_FILE="/tmp/ttytok_gifts"
JOIN_FILE="/tmp/ttytok_joins"
MPV_FILE="/tmp/ttytok_mpv"
STATUS_FILE="/tmp/ttytok_status"

# --- config ---
MAX_RETRIES=5
RETRY_DELAY=2

# --- find and source library ---
for _pt_path in \
    "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/piratetok.sh" \
    "$HOME/.local/lib/piratetok/piratetok.sh" \
    "/usr/local/lib/piratetok/piratetok.sh" \
    "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../live-sh/lib/piratetok.sh"
do
    if [[ -f "$_pt_path" ]]; then
        . "$_pt_path"
        break
    fi
done
[[ -z "$_PT_SOURCED" ]] && { echo "ERROR: piratetok.sh not found" >> "$STATUS_FILE"; exit 1; }

# --- event handlers (write to files) ---
on_chat() { echo "$1: $2" >> "$CHAT_FILE"; }

on_gift() {
    local total_diamonds=$(( $4 * ($3 > 0 ? $3 : 1) ))
    echo "$1 sent $2 x$3 (${total_diamonds} diamonds)" >> "$GIFT_FILE"
}

on_like() { echo "$1 liked ($2 total)" >> "$JOIN_FILE"; }
on_join() { echo "$1 joined" >> "$JOIN_FILE"; }
on_follow() { echo "$1 followed" >> "$JOIN_FILE"; }
on_share() { echo "$1 shared" >> "$JOIN_FILE"; }

on_viewers() {
    tmux set -t ttytok status-right " $1 viewers " 2>/dev/null
}

on_ended() {
    echo "STREAM ENDED" >> "$STATUS_FILE"
    _PT_STREAM_ENDED=1
}

on_status() { echo "$*" >> "$STATUS_FILE"; }
on_error() { echo "ERROR: $*" >> "$STATUS_FILE"; }

# --- extract FLV URL from room response ---
extract_stream_url() {
    _esu_url=$(echo "$PT_ROOM_RESP" | grep -oP '\\"flv\\":\\"((?:[^\\]|\\[^"])*)' | \
        sed 's/\\"flv\\":\\"//;s/\\u0026/\&/g;s/\\\//\//g' | grep -v 'only_audio' | head -1)
    if [ -n "$_esu_url" ]; then
        echo "$_esu_url" >> "$MPV_FILE"
        on_status "stream: got video URL"
    else
        echo "AGE_RESTRICTED" >> "$MPV_FILE"
        on_status "stream: age-restricted (no video without cookies)"
    fi
}

# --- single WSS session ---
wss_session() {
    PT_UA=$(pt_random_ua)

    pt_fetch_ttwid || return 1
    pt_resolve_room "$USERNAME" || return 1

    extract_stream_url

    on_status "CONNECTED to $USERNAME (room $PT_ROOM_ID)"
    pt_wss_open
    pt_read_loop
    pt_wss_close

    [[ "$_PT_STREAM_ENDED" = "1" ]] && return 2
    return 1
}

# --- reconnect loop ---
attempt=0
while (( attempt < MAX_RETRIES )); do
    wss_session
    rc=$?

    [[ $rc -eq 0 || $rc -eq 2 ]] && break

    (( attempt++ ))
    if (( attempt >= MAX_RETRIES )); then
        on_status "DISCONNECTED (max retries)"
        break
    fi

    delay=$(( RETRY_DELAY * (1 << (attempt - 1)) ))
    (( delay > 30 )) && delay=30
    on_status "reconnecting ($attempt/$MAX_RETRIES) in ${delay}s..."
    sleep "$delay"
done
