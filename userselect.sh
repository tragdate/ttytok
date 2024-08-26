#!/bin/bash

ITEMS_FILE="$HOME/.local/share/ttytok/users"
PROCESS_NAME="/usr/local/lib/ttytok/connector" 

cleanup() {
    pkill -f '^$PROCESS_NAME'
    rm -f /tmp/joins /tmp/gifts /tmp/chats
}

trap cleanup EXIT SIGHUP SIGINT SIGTERM SIGKILL

fzf --bind "enter:execute-silent(
    echo 'RESTART_SCREEN_TT' > /tmp/joins;
    echo 'RESTART_SCREEN_TT' > /tmp/gifts;
    echo 'RESTART_SCREEN_TT' > /tmp/chats;
    pkill -f '^$PROCESS_NAME';
    sleep 0.1;
    $PROCESS_NAME {+} > /dev/null 2>&1 &
)" < "$ITEMS_FILE"
