#!/bin/zsh
# run.sh — runs this flow. Each app ticks off when its path appears (paths in config.json), as
# your MDM installs it; nothing else is needed.
#
#   ./run.sh                 run it
#   SD_DIALOG_BIN=… ./run.sh use a specific Dialog build

setopt NULL_GLOB
HERE="${0:A:h}"
# The Dialog that built this folder knows every key in config.json; an older installed copy
# may not. Order: $SD_DIALOG_BIN, then that Dialog, then the installed one, then a dev build.
BUILT_WITH="__BUILT_WITH__"
BIN="$SD_DIALOG_BIN"
[[ -z "$BIN" && -x "$BUILT_WITH" ]] && BIN="$BUILT_WITH"
[[ -z "$BIN" && -x /usr/local/bin/dialog ]] && BIN=/usr/local/bin/dialog
if [[ -z "$BIN" ]]; then
  bins=( ~/Library/Developer/Xcode/DerivedData/dialog-*/Build/Products/Debug/Dialog.app/Contents/MacOS/Dialog(N.om) )
  BIN="${bins[1]}"
fi
[[ -x "$BIN" ]] || { print -u2 "error: no swiftDialog found (install it, or set SD_DIALOG_BIN)"; exit 2 }
exec "$BIN" --inspect-mode --inspect-config "$HERE/config.json"
