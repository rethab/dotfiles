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

# Function to get color based on utilization (expects percentage 0-100)
get_usage_color() {
    local util=$1
    if (( $(echo "$util < 50" | bc -l) )); then
        echo $'\033[32m'  # Green
    elif (( $(echo "$util < 75" | bc -l) )); then
        echo $'\033[33m'  # Yellow
    else
        echo $'\033[31m'  # Red
    fi
}

# Function to format time remaining
format_time_remaining() {
    local resets_at=$1

    # Handle empty input
    if [[ -z "$resets_at" ]]; then
        echo "?"
        return
    fi

    local now=$(date -u +%s)

    # Parse ISO 8601 timestamp with timezone
    # Format: 2026-02-12T18:59:59.669805+00:00
    # Strip microseconds and timezone, keeping just YYYY-MM-DDTHH:MM:SS
    local timestamp=$(echo "$resets_at" | sed -E 's/\.[0-9]+[+-][0-9]{2}:[0-9]{2}$//' | sed -E 's/\.[0-9]+Z$//')
    local reset_time=$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "$timestamp" +%s 2>/dev/null)

    # If parsing failed, try without timezone
    if [[ -z "$reset_time" ]]; then
        reset_time=$(echo "$resets_at" | sed 's/T/ /' | sed 's/\..*//' | xargs -I {} date -j -u -f "%Y-%m-%d %H:%M:%S" "{}" +%s 2>/dev/null || echo $now)
    fi

    local diff=$((reset_time - now))

    if [[ $diff -lt 0 ]]; then
        echo "now"
    elif [[ $diff -lt 3600 ]]; then
        echo "$((diff / 60))m"
    elif [[ $diff -lt 86400 ]]; then
        echo "$((diff / 3600))h"
    else
        echo "$((diff / 86400))d"
    fi
}

# Fetch usage data from API with caching (cache for 60 seconds to avoid rate limits)
CACHE_FILE="/tmp/claude-usage-cache.json"
CACHE_DURATION=60

fetch_usage_data() {
    # Check if cache exists and is fresh
    if [[ -f "$CACHE_FILE" ]]; then
        local cache_age=$(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt $CACHE_DURATION ]]; then
            local cached_data=$(cat "$CACHE_FILE")
            # Only use cache if it's valid JSON and not an error
            if echo "$cached_data" | jq -e '.five_hour' >/dev/null 2>&1; then
                echo "$cached_data"
                return 0
            fi
        fi
    fi

    # Fetch fresh data - get the token from keychain and extract access token
    local token_json=""
    local access_token=""

    # Get the JSON from keychain
    token_json=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)

    if [[ -n "$token_json" ]]; then
        # Parse the JSON to extract the actual access token
        # The keychain stores: {"claudeAiOauth":{"accessToken":"sk-ant-oat01-..."}}
        access_token=$(echo "$token_json" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    fi

    if [[ -n "$access_token" ]]; then
        # Make API call with the extracted access token
        # Note: anthropic-beta header is required for OAuth endpoints
        local response=$(curl -s \
            -H "Authorization: Bearer $access_token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            "https://api.anthropic.com/api/oauth/usage")

        # Check if response is valid and contains expected data (not an error)
        if [[ -n "$response" ]] && echo "$response" | jq -e '.five_hour' >/dev/null 2>&1; then
            echo "$response" > "$CACHE_FILE"
            echo "$response"
            return 0
        fi
    fi

    return 1
}

# Get usage data
usage_data=$(fetch_usage_data 2>/dev/null)
usage_info=""

if [[ -n "$usage_data" ]]; then
    # Parse 5-hour (daily) usage
    five_hour_util=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0' 2>/dev/null)
    five_hour_resets=$(echo "$usage_data" | jq -r '.five_hour.resets_at // ""' 2>/dev/null)

    # Parse 7-day (weekly) usage
    seven_day_util=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0' 2>/dev/null)
    seven_day_resets=$(echo "$usage_data" | jq -r '.seven_day.resets_at // ""' 2>/dev/null)

    # API returns percentages as whole numbers (e.g., 33.0 means 33%), so don't multiply by 100
    # Convert to integer percentages - handle both integer and decimal inputs
    if [[ -n "$five_hour_util" ]] && [[ "$five_hour_util" != "null" ]]; then
        five_hour_pct=$(printf "%.0f" "$five_hour_util" 2>/dev/null || echo "0")
    else
        five_hour_pct="0"
    fi

    if [[ -n "$seven_day_util" ]] && [[ "$seven_day_util" != "null" ]]; then
        seven_day_pct=$(printf "%.0f" "$seven_day_util" 2>/dev/null || echo "0")
    else
        seven_day_pct="0"
    fi

    # Only show if we have valid data (check numeric comparison)
    if [[ "$five_hour_pct" -gt 0 ]] 2>/dev/null || [[ "$seven_day_pct" -gt 0 ]] 2>/dev/null; then
        # Get colors (pass percentage values)
        daily_color=$(get_usage_color "$five_hour_pct" 2>/dev/null || echo $'\033[32m')
        weekly_color=$(get_usage_color "$seven_day_pct" 2>/dev/null || echo $'\033[32m')

        # Format time remaining
        daily_reset=$(format_time_remaining "$five_hour_resets" 2>/dev/null || echo "?")
        weekly_reset=$(format_time_remaining "$seven_day_resets" 2>/dev/null || echo "?")

        # Build usage info string
        usage_info=$(printf ' | 5h: %s%s%%\033[0m (%s) | 7d: %s%s%%\033[0m (%s)' \
            "$daily_color" "$five_hour_pct" "$daily_reset" \
            "$weekly_color" "$seven_day_pct" "$weekly_reset")
    fi

    # Parse extra usage (only show if enabled)
    extra_enabled=$(echo "$usage_data" | jq -r '.extra_usage.is_enabled // false' 2>/dev/null)
    if [[ "$extra_enabled" == "true" ]]; then
        extra_util=$(echo "$usage_data" | jq -r '.extra_usage.utilization // 0' 2>/dev/null)
        extra_used=$(echo "$usage_data" | jq -r '.extra_usage.used_credits // 0' 2>/dev/null)
        extra_limit=$(echo "$usage_data" | jq -r '.extra_usage.monthly_limit // 0' 2>/dev/null)
        extra_pct=$(printf "%.0f" "$extra_util" 2>/dev/null || echo "0")
        extra_color=$(get_usage_color "$extra_pct" 2>/dev/null || echo $'\033[32m')
        extra_used_int=$(printf "%.0f" "$extra_used" 2>/dev/null || echo "0")
        usage_info=$(printf '%s | Extra: %s%s%%\033[0m (%s/%s)' \
            "$usage_info" "$extra_color" "$extra_pct" "$extra_used_int" "$extra_limit")
    fi
fi

# Build the status line
status=""
if [[ "$usage" != "null" ]]; then
    status=$(printf $'\033[36m%s\033[0m in \033[32m%s\033[0m' "$model" "$(basename "$cwd")")
    if [[ -n "$git_branch" ]]; then
        status=$(printf '%s on \033[35m%s\033[0m' "$status" "$git_branch")
    fi
    status=$(printf '%s | Ctx: %s%d%%\033[0m' "$status" "$context_color" "$context_percentage")
else
    # No usage data yet (start of conversation)
    status=$(printf $'\033[36m%s\033[0m in \033[32m%s\033[0m' "$model" "$(basename "$cwd")")
    if [[ -n "$git_branch" ]]; then
        status=$(printf '%s on \033[35m%s\033[0m' "$status" "$git_branch")
    fi
fi

# Append usage info if available
if [[ -n "$usage_info" ]]; then
    status="${status}${usage_info}"
fi

echo "$status"
