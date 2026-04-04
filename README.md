# ttytok

TikTok Live in your terminal. Pure shell, no signing server, no compiled binaries.

tmux multi-pane layout with chat, gifts, joins, video stream, and fzf user picker with live user discovery.

![image](screenshot.png)

## Install

```bash
make install
```

This fetches [piratetok-live-sh](https://github.com/PirateTok/live-sh) (via bpkg or curl) and installs ttytok to `~/.local`.

Dependencies: `bash`, `tmux`, `fzf`, `openssl`, `gzip`. Optional: `mpv` (stream video in terminal).

## Usage

```bash
ttytok                    # open TUI
ttytok add zooich         # add user to watch list
ttytok remove zooich      # remove user
ttytok list               # list saved users
ttytok discover           # browse live users from TikTok feed
ttytok check zooich       # check if a specific user is live
```

### TUI keybindings

| Key | Action |
|-----|--------|
| `Enter` | Connect to selected user |
| `Ctrl-D` | Discover live users (feed browse) |
| `Ctrl-R` | Refresh saved users' online status |
| `Ctrl-A` | Add a new user |
| `Ctrl-X` | Remove selected user |

### Layout

```
+--------+---------------------+
|        | joins/follows       |
| stream +---------------------+
| (mpv)  | gifts               |
|        +---------------------+
|        | chat                |
|        +---------------------+
|        | fzf user picker     |
+--------+---------------------+
```

## How it works

Connects directly to TikTok Live WebSocket via [piratetok-live-sh](https://github.com/PirateTok/live-sh). No API keys, no signing server, no compiled dependencies. Decodes the protobuf event stream and pipes events to tmux panes.

Powered by [PirateTok](https://piratetok.boats).

## Uninstall

```bash
make uninstall
```

## License

0BSD
