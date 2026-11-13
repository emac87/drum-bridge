#!/bin/bash
# Validates DrumBridge with Apple's auval (gives up after 3 minutes). Log: tools/auval.log
cd "$(dirname "$0")"
LOG="$PWD/auval.log"; : > "$LOG"
echo "== validate" >> "$LOG"
auval -v aumi dbmt DBrg >> "$LOG" 2>&1 &
PID=$!
( sleep 180; kill -9 $PID 2>/dev/null && echo "TIMED OUT" >> "$LOG" ) &
wait $PID; echo "AUVAL_EXIT=$?" >> "$LOG"
tail -4 "$LOG"; echo "Done."
osascript -e 'tell application "Terminal" to close (every window whose name contains "auval.command")' >/dev/null 2>&1 &
