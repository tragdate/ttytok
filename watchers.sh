#!/bin/bash

filename=$1

if [ "$filename" != "mpv_ipc" ]; then
  FILE_PATH="/tmp/$filename" 
  SPECIAL_STRING="RESTART_SCREEN_TT"
  touch "$FILE_PATH"
  read_from_start() {
    while IFS= read -r line; do
      if [[ "$line" == *"$SPECIAL_STRING"* ]]; then
        clear
        echo "Detected special string. Restarting file read from start..."
        truncate -s 0 "$FILE_PATH"
        cat "$FILE_PATH"
      fi
    done < "$FILE_PATH"
  }

  tail -n0 -f "$FILE_PATH" 2>/dev/null | while read line; do
  if [[ "$line" == *"$SPECIAL_STRING"* ]]; then
    clear
    truncate -s 0 "$FILE_PATH"
    cat "$FILE_PATH"
  else
    echo "$line"
  fi
done
fi

if [ "$filename" == "mpv_ipc" ]; then
  file_path="/tmp/mpv_ipc"
  if ! command -v inotifywait &>/dev/null; then
    echo "Inotify? Hello? Install that first, bruh."
    exit 1
  fi
  mpv_pid=''
  while inotifywait -e close_write "$file_path"; do
    read -r video_url < "$file_path"
    > "$file_path"
    if [[ $video_url =~ ^https?:// ]]; then
      [[ -n $mpv_pid ]] && kill "$mpv_pid" &>/dev/null && wait "$mpv_pid"
      mpv -vo=tct --really-quiet -- "$video_url" &
      mpv_pid=$!
    else
      echo "C'mon, feed me a real URL, not '$video_url'."
    fi
  done
fi
