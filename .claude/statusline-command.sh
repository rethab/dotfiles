#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values from JSON
model=$(echo "$input" | jq -r '.model.display_name')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')

# Get git branch (skip optional locks to avoid blocking)
git_branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    git_branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
fi

# Get context window usage from actual API data
usage=$(echo "$input" | jq '.context_window.current_usage')
context_percentage=0

if [[ "$usage" != "null" ]]; then
    # Calculate current context tokens (input + cache creation + cache read)
    current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    size=$(echo "$input" | jq '.context_window.context_window_size')

    # Calculate percentage
    if [[ $size -gt 0 ]]; then
        context_percentage=$((current * 100 / size))
    fi
fi

# Color coding for context percentage
context_color=""
if [[ $context_percentage -lt 50 ]]; then
    context_color=$'\033[32m'  # Green for low usage
elif [[ $context_percentage -lt 75 ]]; then
    context_color=$'\033[33m'  # Yellow for medium usage
else
    context_color=$'\033[31m'  # Red for high usage
fi

# Build the status line
status=""
if [[ "$usage" != "null" ]]; then
    status=$(printf $'\033[36m%s\033[0m in \033[32m%s\033[0m' "$model" "$(basename "$cwd")")
    if [[ -n "$git_branch" ]]; then
        status=$(printf '%s on \033[35m%s\033[0m' "$status" "$git_branch")
    fi
    status=$(printf '%s | Context: %s%d%%\033[0m' "$status" "$context_color" "$context_percentage")
else
    # No usage data yet (start of conversation)
    status=$(printf $'\033[36m%s\033[0m in \033[32m%s\033[0m' "$model" "$(basename "$cwd")")
    if [[ -n "$git_branch" ]]; then
        status=$(printf '%s on \033[35m%s\033[0m' "$status" "$git_branch")
    fi
fi

echo "$status"
