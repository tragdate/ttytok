#!/bin/bash

command=$1

if [ "$command" == "add" ]; then
    echo $2 >> "$HOME/.local/share/ttytok/users"
    exit
elif [ "$command" == "remove" ]; then
    sed -i "/$2/d" "$HOME/.local/share/ttytok/users"
    exit
elif [ "$command" == "list" ]; then
    cat "$HOME/.local/share/ttytok/users"
    exit
elif [ "$command" == "addcookies" ]; then
    echo $2 > "$HOME/.local/share/ttytok/cookies"
    exit
fi


touch /tmp/joins
touch /tmp/gifts
touch /tmp/chats
touch /tmp/mpv_ipc

truncate -s 0  /tmp/chats
truncate -s 0  /tmp/gifts
truncate -s 0  /tmp/joins

SESSION_NAME="tt-cli"
SESSION_EXISTS=$(tmux list-sessions | grep $SESSION_NAME)
if [ "$SESSION_EXISTS" = "" ]; then
    tmux new-session -d -s $SESSION_NAME '/usr/local/lib/ttytok/watchers.sh mpv_ipc'
    tmux splitw -h -l 66% '/usr/local/lib/ttytok/watchers.sh joins'
    tmux splitw -v -l 80% -t 1 '/usr/local/lib/ttytok/watchers.sh gifts'
    tmux splitw -v -l 80% -t 2 '/usr/local/lib/ttytok/watchers.sh chats'
    tmux splitw -v -l 10% -t 3 '/usr/local/lib/ttytok/userselect.sh'
    tmux select-pane -t 4
fi

tmux attach -t $SESSION_NAME
