#!/usr/bin/env bash
# ime-switch.sh — Switch IME when the sidebar pane gains/loses focus.
#
# Called from after-select-pane / after-select-window hooks in agent-sidebar.conf.
# Arguments:
#   $1  Value of #{@sidebar_pid} for the newly selected pane.
#       Non-empty  → sidebar pane just gained focus.
#       Empty      → a non-sidebar pane just gained focus.
#
# Required tmux options (set in your tmux.conf or before loading the plugin):
#   @sidebar_ime_switch   "1" to enable (default: disabled)
#   @sidebar_ime_source   Input source ID to activate (default: com.apple.keylayout.ABC)
#
# Optional custom-command overrides (skip im-select entirely when set):
#   @sidebar_ime_enter_cmd  Shell command to run when entering the sidebar
#   @sidebar_ime_leave_cmd  Shell command to run when leaving the sidebar
#                           (receives previous input source as first argument)

SIDEBAR_PID="$1"

# ── Feature gate ─────────────────────────────────────────────────────────────
enabled="$(tmux show-options -gv @sidebar_ime_switch 2>/dev/null)"
[ "$enabled" = "1" ] || exit 0

# ── Helper: switch IME using im-select or a custom command ───────────────────
switch_ime() {
    local target="$1"
    local custom_cmd="$2"
    if [ -n "$custom_cmd" ]; then
        eval "$custom_cmd" 2>/dev/null
    elif command -v im-select &>/dev/null; then
        im-select "$target" 2>/dev/null
    fi
    # silently succeed when no switching mechanism is available
}

get_current_ime() {
    if command -v im-select &>/dev/null; then
        im-select 2>/dev/null
    fi
}

# ── Main logic ────────────────────────────────────────────────────────────────
if [ -n "$SIDEBAR_PID" ]; then
    # Entering sidebar ────────────────────────────────────────────────────────
    enter_cmd="$(tmux show-options -gv @sidebar_ime_enter_cmd 2>/dev/null)"

    if [ -n "$enter_cmd" ]; then
        # User-defined command; they manage save/restore themselves if desired.
        eval "$enter_cmd" 2>/dev/null
    else
        # Save current IME before switching so we can restore it later.
        prev="$(get_current_ime)"
        if [ -n "$prev" ]; then
            tmux set -g @sidebar_prev_ime "$prev"
        fi

        src="$(tmux show-options -gv @sidebar_ime_source 2>/dev/null)"
        [ -z "$src" ] && src="com.apple.keylayout.ABC"
        switch_ime "$src" ""
    fi
else
    # Leaving sidebar (or navigating between non-sidebar panes) ───────────────
    leave_cmd="$(tmux show-options -gv @sidebar_ime_leave_cmd 2>/dev/null)"

    if [ -n "$leave_cmd" ]; then
        eval "$leave_cmd" 2>/dev/null
    else
        prev="$(tmux show-options -gv @sidebar_prev_ime 2>/dev/null)"
        if [ -n "$prev" ]; then
            switch_ime "$prev" ""
            tmux set -g @sidebar_prev_ime ""
        fi
    fi
fi
