#!/bin/bash
#
# Preset6 Apple Design Quality Uplift — Interactive Test Script
#
# Tests: transitions, back button overlay, content width, forms, sidebar nav, scrolling
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIALOG_BIN="${SD_DIALOG_BIN:-/Users/henry/Projects/open-source/build/Dialog.app/Contents/MacOS/dialogcli}"
CONFIG="$SCRIPT_DIR/config.json"
TRIGGER="/tmp/swiftdialog_dev_preset6.trigger"

# Colors
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' B='\033[0;34m' C='\033[0;36m' D='\033[2m' NC='\033[0m'

pass_count=0
fail_count=0
skip_count=0

result() {
    local verdict="$1" label="$2"
    case "$verdict" in
        pass) echo -e "  ${G}PASS${NC}  $label"; ((pass_count++)) ;;
        fail) echo -e "  ${R}FAIL${NC}  $label"; ((fail_count++)) ;;
        skip) echo -e "  ${D}SKIP${NC}  $label"; ((skip_count++)) ;;
    esac
}

ask() {
    local prompt="$1"
    echo ""
    echo -e "${C}$prompt${NC}"
    echo -e "${D}  [y] pass  [n] fail  [s] skip  [q] quit${NC}"
    read -rsn1 key
    case "$key" in
        y|Y) echo "pass" ;;
        n|N) echo "fail" ;;
        s|S) echo "skip" ;;
        q|Q) echo "quit" ;;
        *)   echo "pass" ;;  # Enter = pass
    esac
}

send() {
    echo "$1" > "$TRIGGER"
    sleep 0.3
}

# ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${B}  Preset6 Apple Design Quality Uplift — Test Suite${NC}"
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Preflight
if [ ! -f "$DIALOG_BIN" ]; then
    echo -e "${R}ERROR: dialogcli not found at $DIALOG_BIN${NC}"
    echo "  Build first: ./ad-hoc-build.sh"
    exit 1
fi

# Clean state
defaults delete com.swiftdialog.preset6 2>/dev/null
rm -f "$TRIGGER"

echo -e "${Y}Launching Dialog...${NC}"
"$DIALOG_BIN" --inspect-mode --inspect-config "$CONFIG" &
DIALOG_PID=$!
sleep 2

if ! kill -0 "$DIALOG_PID" 2>/dev/null; then
    echo -e "${R}ERROR: Dialog failed to launch${NC}"
    exit 1
fi
echo -e "${G}Dialog running (PID: $DIALOG_PID)${NC}"

# ─────────────────────────────────────────────────────────────────
# Test 1: Window Size
# ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${B}── Test 1: Window Size ──${NC}"
echo -e "  Expected: 860×620 (narrower than old 1024×640)"
echo -e "  The window should feel proportional, not too wide."

v=$(ask "Does the window look approximately 860×620?")
[ "$v" = "quit" ] && { kill "$DIALOG_PID" 2>/dev/null; exit 0; }
result "$v" "Window size 860×620"

# ─────────────────────────────────────────────────────────────────
# Test 2: Intro Step — No Back Button
# ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${B}── Test 2: Intro Step ──${NC}"
echo -e "  You should see the intro (full-screen, no sidebar)."
echo -e "  There should be NO floating back button."

v=$(ask "Is the intro full-screen with no back button overlay?")
[ "$v" = "quit" ] && { kill "$DIALOG_PID" 2>/dev/null; exit 0; }
result "$v" "Intro: no back button"

echo ""
echo -e "${Y}Click 'Begin Tests' in the dialog to continue...${NC}"
echo -e "${D}(press any key after clicking)${NC}"
read -rsn1

# ─────────────────────────────────────────────────────────────────
# Test 3: Forward Transition
# ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${B}── Test 3: Forward Transition ──${NC}"
echo -e "  You should now be on 'Transition Direction Test'."
echo -e "  The content should have slid in from the RIGHT."

v=$(ask "Did content slide in from the right (forward direction)?")
[ "$v" = "quit" ] && { kill "$DIALOG_PID" 2>/dev/null; exit 0; }
result "$v" "Forward transition: slide left-out/right-in"

# ─────────────────────────────────────────────────────────────────
# Test 4: Floating Back Button
# ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${B}── Test 4: Floating Back Button ──${NC}"
echo -e "  Look at the TOP-LEFT of the content panel."
echo -e "  There should be a circular chevron back button."

v=$(ask "Is there a floating back button at top-left of content panel?")
[ "$v" = "quit" ] && { kill "$DIALOG_PID" 2>/dev/null; exit 0; }
result "$v" "Back button: floating overlay at top-left"

# ─────────────────────────────────────────────────────────────────
# Test 5: Footer Bar — No Back Button
# ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${B}── Test 5: Footer Bar ──${NC}"
echo -e "  Look at the footer bar (bottom of window)."
echo -e "  It should show: step counter + Continue button."
echo -e "  There should be NO back button in the footer."

v=$(ask "Is the footer clean (no back button, just counter + Continue)?")
[ "$v" = "quit" ] && { kill "$DIALOG_PID" 2>/dev/null; exit 0; }
result "$v" "Footer: no back button"

# ─────────────────────────────────────────────────────────────────
# Test 6: Backward Transition
# ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${B}── Test 6: Backward Transition ──${NC}"
echo -e "${Y}Click the floating back button (top-left chevron) now...${NC}"
echo -e "${D}(press any key after clicking)${NC}"
read -rsn1

echo -e "  The intro should now be showing (slid in from the LEFT)."
echo -e "${Y}Now click 'Begin Tests' again to come back...${NC}"
echo -e "${D}(press any key after clicking)${NC}"
read -rsn1

v=$(ask "Did backward slide right-out/left-in, then forward slide left-out/right-in?")
[ "$v" = "quit" ] && { kill "$DIALOG_PID" 2>/dev/null; exit 0; }
result "$v" "Backward transition: slide right-out/left-in"

# ─────────────────────────────────────────────────────────────────
# Test 7: Content Width
# Navigate to step 3 (Content Width)
# ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${Y}Click Continue twice to reach 'Content Width' step...${NC}"
echo -e "${D}(press any key when on the Content Width step)${NC}"
read -rsn1

echo ""
echo -e "${B}── Test 7: Content Width Constraint ──${NC}"
echo -e "  Text should be constrained to ~420pt width."
echo -e "  There should be breathing room on BOTH sides."
echo -e "  Text should NOT stretch across the full content panel."

v=$(ask "Is the text constrained with visible margins on both sides?")
[ "$v" = "quit" ] && { kill "$DIALOG_PID" 2>/dev/null; exit 0; }
result "$v" "Content width: 420pt constraint centered"

# ─────────────────────────────────────────────────────────────────
# Test 8: Form Elements
# Navigate to step 4 (Forms)
# ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${Y}Click Continue to reach 'Forms' step...${NC}"
echo -e "${D}(press any key when on the Forms step)${NC}"
read -rsn1

echo ""
echo -e "${B}── Test 8: Form Elements at 420pt ──${NC}"
echo -e "  Checkboxes, dropdown, text field, and slider"
echo -e "  should all render within the 420pt column."

v=$(ask "Do form elements render properly within the constrained width?")
[ "$v" = "quit" ] && { kill "$DIALOG_PID" 2>/dev/null; exit 0; }
result "$v" "Forms: render within 420pt column"

# ─────────────────────────────────────────────────────────────────
# Test 9: Sidebar Navigation Direction
# ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${Y}Click Continue to reach 'Sidebar Nav' step...${NC}"
echo -e "${D}(press any key when on Sidebar Nav step)${NC}"
read -rsn1

echo ""
echo -e "${B}── Test 9: Sidebar Navigation Direction ──${NC}"
echo -e "${Y}Click 'Transitions' (step 2) in the sidebar...${NC}"
echo -e "${D}(press any key after clicking)${NC}"
read -rsn1

echo -e "  Content should have slid RIGHT (backward direction)."
echo -e "${Y}Now click 'Sidebar Nav' (step 6) in the sidebar...${NC}"
echo -e "${D}(press any key after clicking)${NC}"
read -rsn1

v=$(ask "Did sidebar clicks use correct transition directions?")
[ "$v" = "quit" ] && { kill "$DIALOG_PID" 2>/dev/null; exit 0; }
result "$v" "Sidebar nav: direction-aware transitions"

# ─────────────────────────────────────────────────────────────────
# Test 10: Scroll Content
# ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${Y}Click Continue to reach 'Long Content' step...${NC}"
echo -e "${D}(press any key when on the Long Content step)${NC}"
read -rsn1

echo ""
echo -e "${B}── Test 10: Scroll & Overflow ──${NC}"
echo -e "  Content should overflow and be scrollable."
echo -e "  A subtle scroll hint gradient may appear at the bottom."
echo -e "  The back button should stay fixed (not scroll with content)."

v=$(ask "Does scrolling work with the back button staying fixed?")
[ "$v" = "quit" ] && { kill "$DIALOG_PID" 2>/dev/null; exit 0; }
result "$v" "Scroll: content scrolls, back button fixed"

# ─────────────────────────────────────────────────────────────────
# Test 11: Outro — No Floating Back Button
# ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${Y}Click Continue to reach the 'Complete' outro step...${NC}"
echo -e "${D}(press any key when on the outro)${NC}"
read -rsn1

echo ""
echo -e "${B}── Test 11: Outro Step ──${NC}"
echo -e "  Full-screen outro (no sidebar)."
echo -e "  The floating back button should NOT appear here"
echo -e "  (the IntroStepContainer has its own back button)."

v=$(ask "Is the outro full-screen with no floating back button overlay?")
[ "$v" = "quit" ] && { kill "$DIALOG_PID" 2>/dev/null; exit 0; }
result "$v" "Outro: no floating back button"

# ─────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${Y}Click 'Finish' to close the dialog...${NC}"
echo -e "${D}(or just close the window)${NC}"
wait "$DIALOG_PID" 2>/dev/null

echo ""
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${B}  Test Results${NC}"
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
total=$((pass_count + fail_count + skip_count))
echo -e "  ${G}Passed:${NC}  $pass_count / $total"
echo -e "  ${R}Failed:${NC}  $fail_count / $total"
[ $skip_count -gt 0 ] && echo -e "  ${D}Skipped:${NC} $skip_count / $total"
echo ""

if [ $fail_count -eq 0 ]; then
    echo -e "  ${G}All tests passed!${NC}"
    exit 0
else
    echo -e "  ${R}$fail_count test(s) failed.${NC}"
    exit 1
fi
