#!/bin/bash

# ANSI color constants
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
CYAN=$'\033[36m'; MAGENTA=$'\033[35m'; RESET=$'\033[0m'

# Read JSON input from stdin
input=$(</dev/stdin)

# Extract all needed values from input JSON in a single jq call
IFS=$'\t' read -r model cwd current size git_worktree <<< "$(jq -r '[
  .model.display_name,
  .workspace.current_dir,
  ((.context_window.current_usage // {}) | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))),
  (.context_window.context_window_size // 0),
  (.workspace.git_worktree // "")
] | @tsv' <<< "$input")"

# Detect whether we have context usage data
has_context=false
context_percentage=0
if [[ "$current" != "0" || "$size" != "0" ]] && [[ "$size" -gt 0 ]] 2>/dev/null; then
    has_context=true
    context_percentage=$((current * 100 / size))
fi

# Get git branch (skip optional locks to avoid blocking)
git_branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    git_branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
fi

# Returns green/yellow/red ANSI code based on percentage (integer)
get_usage_color() {
    local util=${1%.*}  # truncate any decimal
    if [[ $util -lt 50 ]]; then
        echo "$GREEN"
    elif [[ $util -lt 75 ]]; then
        echo "$YELLOW"
    else
        echo "$RED"
    fi
}

# Takes a Unix epoch timestamp and returns human-readable time remaining
format_time_remaining() {
    local reset_time=$1
    if [[ -z "$reset_time" || "$reset_time" == "0" ]]; then
        echo "?"
        return
    fi

    local now=$(date +%s)
    local diff=$((reset_time - now))
    if [[ $diff -lt 0 ]]; then
        echo "??"
    elif [[ $diff -lt 3600 ]]; then
        echo "$((diff / 60))m"
    elif [[ $diff -lt 86400 ]]; then
        echo "$((diff / 3600))h"
    else
        echo "$((diff / 86400))d"
    fi
}

# Rounds a utilization value to an integer percentage, defaulting to 0
parse_pct() {
    local v=$1
    if [[ -n "$v" && "$v" != "null" ]]; then
        printf "%.0f" "$v"
    else
        echo "0"
    fi
}

# Extract rate_limits from the native statusline JSON (added in v2.1.80)
# This replaces the old workaround that fetched from /api/oauth/usage directly
usage_info=""
IFS=$'\x1e' read -r five_hour_pct five_hour_resets \
                     seven_day_pct seven_day_resets \
    <<< "$(jq -r '[
      (.rate_limits.five_hour.used_percentage // 0),
      (.rate_limits.five_hour.resets_at // ""),
      (.rate_limits.seven_day.used_percentage // 0),
      (.rate_limits.seven_day.resets_at // "")
    ] | join("\u001e")' <<< "$input")"

five_hour_pct=$(parse_pct "$five_hour_pct")
seven_day_pct=$(parse_pct "$seven_day_pct")

if [[ "$five_hour_pct" -gt 0 ]] 2>/dev/null || [[ "$seven_day_pct" -gt 0 ]] 2>/dev/null; then
    daily_color=$(get_usage_color "$five_hour_pct")
    weekly_color=$(get_usage_color "$seven_day_pct")
    daily_reset=$(format_time_remaining "$five_hour_resets")
    weekly_reset=$(format_time_remaining "$seven_day_resets")

    usage_info=$(printf ' | 5h: %s%s%%%s (%s) | 7d: %s%s%%%s (%s)' \
        "$daily_color" "$five_hour_pct" "$RESET" "$daily_reset" \
        "$weekly_color" "$seven_day_pct" "$RESET" "$weekly_reset")
fi

# Build the status line (common prefix, conditional context suffix)
status=$(printf '%s%s%s in %s%s%s' "$CYAN" "$model" "$RESET" "$GREEN" "$(basename "$cwd")" "$RESET")
if [[ -n "$git_branch" ]]; then
    status=$(printf '%s on %s%s%s' "$status" "$MAGENTA" "$git_branch" "$RESET")
fi
if [[ -n "$git_worktree" ]]; then
    status=$(printf '%s %s[worktree:%s]%s' "$status" "$YELLOW" "$git_worktree" "$RESET")
fi
if [[ "$has_context" == "true" ]]; then
    context_color=$(get_usage_color "$context_percentage")
    status=$(printf '%s | Ctx: %s%d%%%s' "$status" "$context_color" "$context_percentage" "$RESET")
fi
if [[ -n "$usage_info" ]]; then
    status="${status}${usage_info}"
fi

echo "$status"
