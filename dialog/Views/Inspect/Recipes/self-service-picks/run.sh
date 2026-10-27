#!/bin/zsh
# run.sh — runs this flow and does the work for each option it ends up running.
#
# The dialog decides WHAT runs: the picks, plus what they include, less what they cancel (the
# rules are on the cards in config.json). This script asks the running dialog for that plan,
# does each piece of work in do_work, and reports it done — one line, cadence:satisfy:<id> —
# which ticks it off on screen.
#
#   ./run.sh                 run it
#   SD_DIALOG_BIN=… ./run.sh use a specific Dialog build

setopt NULL_GLOB
HERE="${0:A:h}"
CFG="$HERE/config.json"

# ── YOUR WORK ─────────────────────────────────────────────────────────────────────────────────
# Called once per option that runs, in run order, with the option's id. Replace the sleep with
# the real work; return non-zero to leave the option unticked.
do_work() {
  local id="$1"
  case "$id" in
    *) sleep 1 ;;            # e.g.  clear_caches) /usr/local/bin/clear-caches ;;
  esac
}
# ──────────────────────────────────────────────────────────────────────────────────────────────

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

# JSON is read with JavaScript for Automation, which every Mac has (a stock Mac has no Python).
jsread() {   # jsread <function body; r(path) parses a JSON file; a = the arguments> <arguments…>
  /usr/bin/osascript -l JavaScript -e "ObjC.import('Foundation')
function r(p) { return JSON.parse(\$.NSString.stringWithContentsOfFileEncodingError(p, \$.NSUTF8StringEncoding, null).js) }
function run(a) { $1 }" "${@:2}"
}
read_cfg() { jsread 'return r(a[0])[a[1]] || ""' "$CFG" "$1" }
TRIGGER="$(read_cfg triggerFile)"; EVENTS="$(read_cfg eventFile)"
[[ -n "$TRIGGER" ]] && : >| "$TRIGGER"; [[ -n "$EVENTS" ]] && : >| "$EVENTS"
send() { print -r -- "$1" >> "$TRIGGER" }
started() { grep -q "\"stepId\":\"$1\"" "$EVENTS" 2>/dev/null && grep "\"stepId\":\"$1\"" "$EVENTS" | grep -q step_started }

# The progress step and the chooser's key, from the config itself.
read -r RUN_STEP KEY <<< "$(jsread 'const steps = r(a[0]).introSteps
  const chooser = steps.find(s => s.stepType == "options" && s.optionMultiSelect) || {}
  return ((steps.find(s => s.stepType == "cadence") || {}).id || "") + " " + (chooser.optionKey || chooser.id || "")' "$CFG")"

"$BIN" --inspect-mode --inspect-config "$CFG" >/dev/null 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null' INT TERM

# Wait for the progress screen, then ask the dialog for its plan.
while kill -0 $PID 2>/dev/null && ! started "$RUN_STEP"; do sleep 0.5; done
kill -0 $PID 2>/dev/null || exit 0
: >| "$TRIGGER.steps.json"; send "step_list"
for i in {1..20}; do [[ -s "$TRIGGER.steps.json" ]] && break; sleep 0.2; done
PLAN=( $(jsread 'const run = (r(a[0]).selections || {})[a[2] + ".run"] || []
  const cards = r(a[1]).introSteps.find(s => s.stepType == "options" && s.optionMultiSelect).optionCards
  return cards.map((c, i) => [c.runOrder || 0, i, c.id]).filter(t => run.includes(t[2]))
    .sort((x, y) => x[0] - y[0] || x[1] - y[1]).map(t => t[2]).join(" ")' "$TRIGGER.steps.json" "$CFG" "$KEY") )

for id in $PLAN; do
  print "running $id"
  do_work "$id" && send "cadence:satisfy:$id"
done
wait $PID
