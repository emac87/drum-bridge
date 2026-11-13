#!/bin/bash
# Refreshes macOS's Audio Unit list and validates DrumBridge. Log: tools/auval.log
cd "$(dirname "$0")"
LOG="$PWD/auval.log"; : > "$LOG"
killall -9 AudioComponentRegistrar >/dev/null 2>&1
sleep 3
echo "== auval -a" >> "$LOG"; auval -a 2>&1 | grep -iE "dbrg|drumbridge" >> "$LOG"
echo "== validate" >> "$LOG"; auval -v aumi dbmt DBrg >> "$LOG" 2>&1; echo "AUVAL_EXIT=$?" >> "$LOG"
tail -4 "$LOG"; echo "Done."
osascript -e 'tell application "Terminal" to close (every window whose name contains "auval.command")' >/dev/null 2>&1 &
