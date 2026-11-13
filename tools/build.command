#!/bin/bash
# Builds DrumBridge (Mac), installs it to /Applications, registers the Audio Unit and runs auval.
# Log for Claude: tools/build.log
cd "$(dirname "$0")/.."
LOG="$PWD/tools/build.log"
WB="$HOME/Documents/Claude Workbench"
: > "$LOG"
say() { echo "$@" | tee -a "$LOG"; }

# XcodeGen (kept in the Workbench so it's never downloaded twice)
XG="$(command -v xcodegen)"
if [ -z "$XG" ]; then
  XG="$WB/tools/xcodegen/bin/xcodegen"
  if [ ! -x "$XG" ] && [ -f "$WB/installers/xcodegen.zip" ]; then
    mkdir -p "$WB/tools" && (cd "$WB/tools" && unzip -oq "$WB/installers/xcodegen.zip")
    chmod +x "$XG"; xattr -dr com.apple.quarantine "$WB/tools/xcodegen" 2>/dev/null
  fi
fi
say "== xcodegen: $XG"
"$XG" generate >> "$LOG" 2>&1 || { say "XCODEGEN FAILED"; exit 1; }

say "== building (Release)"
xcodebuild -project DrumBridge.xcodeproj -scheme DrumBridge -configuration Release \
  -derivedDataPath build -allowProvisioningUpdates build >> "$LOG" 2>&1
RC=$?
grep -E "error:|BUILD (SUCCEEDED|FAILED)" "$LOG" | tail -40
say "BUILD_EXIT=$RC"
if [ $RC -ne 0 ]; then say "Build failed - tell Claude."; exit 1; fi

say "== installing to /Applications"
APP="build/Build/Products/Release/DrumBridge.app"
osascript -e 'tell application "DrumBridge" to quit' >/dev/null 2>&1
rm -rf /Applications/DrumBridge.app && cp -R "$APP" /Applications/ >> "$LOG" 2>&1 || say "COPY FAILED"
codesign -dv /Applications/DrumBridge.app/Contents/PlugIns/DrumBridgeAU.appex >> "$LOG" 2>&1
open /Applications/DrumBridge.app
sleep 4
pluginkit -a /Applications/DrumBridge.app/Contents/PlugIns/DrumBridgeAU.appex >> "$LOG" 2>&1
say "== pluginkit"
pluginkit -mv -p com.apple.AudioUnit-UI 2>&1 | grep -i drumbridge | tee -a "$LOG"
say "== auval"
killall -9 AudioComponentRegistrar >/dev/null 2>&1; sleep 3
auval -v aumi dbmt DBrg >> "$LOG" 2>&1
AV=$?
tail -5 "$LOG"
say "AUVAL_EXIT=$AV"
say "Done. You can close this window."
osascript -e 'tell application "Terminal" to close (every window whose name contains "build.command")' >/dev/null 2>&1 &
