#!/bin/bash

OUTDIR="$HOME/Videos/Recordings"
PIDFILE="/tmp/wf-recorder.pid"

mkdir -p "$OUTDIR"

# =====================
# Stop recording
# =====================
if [[ -f "$PIDFILE" ]]; then
    PID="$(cat "$PIDFILE")"
    if kill -0 "$PID" 2>/dev/null; then
        kill -INT "$PID"
        rm -f "$PIDFILE"
        notify-send "Screen Recorder" "⏹ Recording stopped"
        exit 0
    else
        rm -f "$PIDFILE"
    fi
fi

# =====================
# Menu
# =====================
choice=$(
printf "%s\n" \
  "󰑋 Full Screen" \
  "󰍹 Select Region" \
  "󰍺 Select Monitor" \
  "󰙧 Cancel" |
fzf --prompt="Screen Recorder > " --height=40% --border
)

[[ -z "$choice" || "$choice" == *Cancel* ]] && exit 0

FILE="$OUTDIR/rec-$(date +'%Y-%m-%d_%H-%M-%S').mp4"

# =====================
# Start recording
# =====================
case "$choice" in
    *Full*)
        wf-recorder -a -f "$FILE" &
        ;;
    *Region*)
        GEOM="$(slurp)"
        [[ -z "$GEOM" ]] && exit 0
        wf-recorder -a -g "$GEOM" -f "$FILE" &
        ;;
    *Monitor*)
        MONITOR=$(hyprctl monitors | awk '/Monitor/{print $2}' | fzf --prompt="Select Monitor > ")
        [[ -z "$MONITOR" ]] && exit 0
        wf-recorder -a -o "$MONITOR" -f "$FILE" &
        ;;
esac

echo $! > "$PIDFILE"
notify-send "Screen Recorder" "󰻂 Recording started (System Audio)"
