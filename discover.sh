#!/bin/bash
# ttytok discover — fetch live users from TikTok feed API
# Hits a category channel, outputs: username<TAB>viewers<TAB>title

# locale detection
SYS_LANG="${LANG%%.*}"
BROWSER_LANG="${SYS_LANG//_/-}"
: "${BROWSER_LANG:=en-US}"
REGION="${SYS_LANG##*_}"
[[ ${#REGION} -ne 2 ]] && REGION="US"

UA_POOL=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0"
    "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
)
UA="${UA_POOL[$((RANDOM % ${#UA_POOL[@]}))]}"

# category → channel params
declare -A CATEGORIES
CATEGORIES=(
    [recommended]="86&req_from=pc_web_recommend_room"
    [suggested]="86&req_from=pc_web_suggested_host&content_type=0"
    [popular]="85&req_from=pc_web_suggested_host"
    [trending]="87&req_from=live_mt_pc_web_rec_tab_refresh"
    [chatting]="1222001&req_from=webapp_taxonomy_drawer_enter_feed&related_live_tag=chatting"
    [fashion]="1222002&req_from=webapp_taxonomy_drawer_enter_feed&related_live_tag=fashion"
    [lifestyle]="1222003&req_from=webapp_taxonomy_drawer_enter_feed&related_live_tag=lifestyle"
    [outdoor]="1222004&req_from=webapp_taxonomy_drawer_enter_feed&related_live_tag=outdoor"
    [gaming]="1111006&req_from=pc_web_game_sub_feed_refresh"
    [minecraft]="1111006&req_from=pc_web_game_sub_feed_refresh&related_live_tag=Minecraft"
    [fortnite]="1111006&req_from=pc_web_game_sub_feed_refresh&related_live_tag=Fortnite"
    [valorant]="1111006&req_from=pc_web_game_sub_feed_refresh&related_live_tag=VALORANT"
)

# default: random from a few good ones
DEFAULT_CATS=(recommended suggested popular trending chatting gaming)
CATEGORY="${1:-${DEFAULT_CATS[$((RANDOM % ${#DEFAULT_CATS[@]}))]}}"

CH="${CATEGORIES[$CATEGORY]}"
if [[ -z "$CH" ]]; then
    echo "unknown category: $CATEGORY" >&2
    echo "available: ${!CATEGORIES[*]}" >&2
    exit 1
fi

FEED_PATH="/webcast/feed/?aid=1988&app_name=tiktok_web&device_platform=web_pc&browser_language=${BROWSER_LANG}&app_language=en&user_is_login=false&device_id=${RANDOM}${RANDOM}${RANDOM}&region=${REGION}&channel_id=${CH}"

RESP=$({
    printf 'GET %s HTTP/1.0\r\n' "$FEED_PATH"
    printf 'Host: webcast.tiktok.com\r\n'
    printf 'User-Agent: %s\r\n' "$UA"
    printf 'Accept: application/json\r\n'
    printf 'Accept-Encoding: identity\r\n'
    printf '\r\n'
} | openssl s_client -connect "webcast.tiktok.com:443" -quiet 2>/dev/null)

[[ -z "$RESP" ]] && exit 1

BODY=$(echo "$RESP" | sed '1,/^\r*$/d')
[[ -z "$BODY" ]] && exit 1

declare -A SEEN
TF="/tmp/ttytok_disc_$$"
echo "$BODY" | grep -oP '"display_id"\s*:\s*"[^"]*"' | sed 's/"display_id"\s*:\s*"//;s/"//' > "${TF}_u"
echo "$BODY" | grep -oP '"user_count"\s*:\s*[0-9]+' | sed 's/"user_count"\s*:\s*//' > "${TF}_v"
echo "$BODY" | grep -oP '"title"\s*:\s*"[^"]*"' | sed 's/"title"\s*:\s*"//;s/"//' > "${TF}_t"

while IFS='|' read -r user viewers title; do
    [[ -z "$user" || -n "${SEEN[$user]}" ]] && continue
    SEEN[$user]=1
    title=$(echo "$title" | tr '\t\n' '  ' | cut -c1-60)
    printf '%s\t%s\t%s\n' "$user" "${viewers:-0}" "$title"
done < <(paste -d'|' "${TF}_u" "${TF}_v" "${TF}_t")

rm -f "${TF}_u" "${TF}_v" "${TF}_t"
