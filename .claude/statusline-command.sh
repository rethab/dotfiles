#!/bin/bash

# ANSI color constants
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
CYAN=$'\033[36m'; MAGENTA=$'\033[35m'; RESET=$'\033[0m'

# Read JSON input from stdin
input=$(</dev/stdin)

# Extract all needed values from input JSON in a single jq call
IFS=$'\t' read -r model cwd cc_version current size <<< "$(jq -r '[
  .model.display_name,
  .workspace.current_dir,
  (.version // "2.1.72"),
  ((.context_window.current_usage // {}) | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))),
  (.context_window.context_window_size // 0)
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

# Parses ISO 8601 timestamp and returns human-readable time remaining
format_time_remaining() {
    local resets_at=$1
    if [[ -z "$resets_at" ]]; then
        echo "?"
        return
    fi

    local now=$(date -u +%s)
    # Strip fractional seconds + timezone using bash parameter expansion (no sed)
    local timestamp="${resets_at%%.*}"
    local reset_time=$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "$timestamp" +%s 2>/dev/null)

    if [[ -z "$reset_time" ]]; then
        echo "?"
        return
    fi

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

CACHE_FILE="/tmp/claude-usage-cache.json"
CACHE_FETCH_TS="/tmp/claude-usage-fetched.ts"  # tracks last successful fetch time
CACHE_RETRY_TS="/tmp/claude-usage-retry.ts"    # tracks last retry attempt
CACHE_LOCK="/tmp/claude-usage-fetch.lock"       # prevents concurrent fetches across instances
CACHE_DURATION=120

# Emits stale cache data if available; returns 2 (stale) or 1 (no data)
emit_stale_cache() {
    if [[ -f "$CACHE_FILE" ]]; then
        local stale_data=$(cat "$CACHE_FILE")
        if jq -e '.five_hour' <<< "$stale_data" >/dev/null 2>&1; then
            echo "$stale_data"
            return 2  # stale
        fi
    fi
    return 1
}

fetch_usage_data() {
    local now=$(date +%s)

    # Check if we have cached data and a recent successful fetch
    if [[ -f "$CACHE_FILE" && -f "$CACHE_FETCH_TS" ]]; then
        local fetched_at=$(cat "$CACHE_FETCH_TS")
        local cache_age=$((now - fetched_at))
        if [[ $cache_age -lt $CACHE_DURATION ]]; then
            local cached_data=$(cat "$CACHE_FILE")
            if jq -e '.five_hour' <<< "$cached_data" >/dev/null 2>&1; then
                echo "$cached_data"
                return 0  # fresh
            fi
        fi
    fi

    # Don't retry if we failed recently (wait CACHE_DURATION between attempts)
    if [[ -f "$CACHE_RETRY_TS" ]]; then
        local last_retry=$(cat "$CACHE_RETRY_TS")
        if [[ $((now - last_retry)) -lt $CACHE_DURATION ]]; then
            # Too soon to retry — return stale cache if available
            emit_stale_cache
            return $?
        fi
    fi

    # Use a lockfile to prevent multiple concurrent Claude instances from all
    # hitting the API simultaneously when the cache expires (thundering herd).
    # noclobber (set -C) makes the redirect atomic: only one process succeeds.
    local got_lock=false
    if ( set -C; echo "$$" > "$CACHE_LOCK" ) 2>/dev/null; then
        got_lock=true
    elif [[ -f "$CACHE_LOCK" ]]; then
        # Stale lock recovery: remove if >10s old or holding PID is dead
        local lock_pid=$(cat "$CACHE_LOCK")
        local lock_age=$(( now - $(stat -f %m "$CACHE_LOCK" 2>/dev/null || echo "$now") ))
        if [[ $lock_age -gt 10 ]] || ! kill -0 "$lock_pid" 2>/dev/null; then
            rm -f "$CACHE_LOCK"
            if ( set -C; echo "$$" > "$CACHE_LOCK" ) 2>/dev/null; then
                got_lock=true
            fi
        fi
    fi
    if [[ "$got_lock" == "true" ]]; then
        trap 'rm -f "$CACHE_LOCK"' RETURN INT TERM HUP

        # Fetch fresh data from keychain
        local token_json=""
        local access_token=""
        token_json=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if [[ -n "$token_json" ]]; then
            access_token=$(jq -r '.claudeAiOauth.accessToken // empty' <<< "$token_json" 2>/dev/null)
        fi

        if [[ -n "$access_token" ]]; then
            # User-Agent must match claude-code/* to avoid stricter rate limit bucket
            # See: https://github.com/anthropics/claude-code/issues/30930#issuecomment-4032624631
            local resp_body="/tmp/claude-usage-resp-$$.json"
            local resp_headers="/tmp/claude-usage-resp-headers-$$.txt"
            local http_code=$(curl -s --max-time 3 -o "$resp_body" -D "$resp_headers" \
                -w '%{http_code}' \
                -H "Authorization: Bearer $access_token" \
                -H "anthropic-beta: oauth-2025-04-20" \
                -H "User-Agent: claude-code/${cc_version}" \
                "https://api.anthropic.com/api/oauth/usage")
            local response=$(cat "$resp_body" 2>/dev/null)
            local rate_headers=$(grep -iE 'rate|limit|retry|reset' "$resp_headers" 2>/dev/null | tr '\r\n' ' ')
            rm -f "$resp_body" "$resp_headers"

            # Log API call (keep log bounded to ~1000 lines)
            local log_file="/tmp/claude-api-calls.log"
            echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') pid=$$ http=$http_code headers=[$rate_headers] response=$response" >> "$log_file"
            if [[ $(wc -l < "$log_file" 2>/dev/null) -gt 1000 ]]; then
                tail -500 "$log_file" > "$log_file.tmp" && mv "$log_file.tmp" "$log_file"
            fi

            if [[ -n "$response" ]] && jq -e '.five_hour' <<< "$response" >/dev/null 2>&1; then
                echo "$response" > "$CACHE_FILE"
                echo "$now" > "$CACHE_FETCH_TS"
                # Clear any previous retry timestamp on success
                rm -f "$CACHE_RETRY_TS"
                echo "$response"
                return 0  # fresh
            fi
        fi

        # Fetch failed — record retry time and fall back to stale cache
        echo "$now" > "$CACHE_RETRY_TS"
    fi

    emit_stale_cache
}

# Get usage data
usage_data=$(fetch_usage_data)
usage_fetch_rc=$?
usage_info=""

if [[ -n "$usage_data" ]]; then
    # Extract all usage fields in a single jq call (use non-whitespace
    # delimiter so bash read preserves empty fields like missing resets_at)
    IFS=$'\x1e' read -r five_hour_util five_hour_resets \
                         seven_day_util seven_day_resets \
                         extra_enabled extra_util extra_used extra_limit \
        <<< "$(jq -r '[
          (.five_hour.utilization // 0),
          (.five_hour.resets_at // ""),
          (.seven_day.utilization // 0),
          (.seven_day.resets_at // ""),
          (.extra_usage.is_enabled // false),
          (.extra_usage.utilization // 0),
          (.extra_usage.used_credits // 0),
          (.extra_usage.monthly_limit // 0)
        ] | join("\u001e")' <<< "$usage_data")"

    five_hour_pct=$(parse_pct "$five_hour_util")

    # rc=2 means stale, but only show STALE indicator if data is more than
    # CACHE_DURATION+60 seconds old — gives the fetching process a 60s grace
    # period before anything is actually labelled stale (avoids a brief flash
    # during the normal cache-refresh window).
    now_main=$(date +%s)
    fetched_at_check=0
    [[ -f "$CACHE_FETCH_TS" ]] && fetched_at_check=$(cat "$CACHE_FETCH_TS")
    data_age=$(( now_main - fetched_at_check ))
    if [[ "$usage_fetch_rc" -eq 2 && "$data_age" -le $(( CACHE_DURATION + 60 )) ]]; then
        # Within grace period: treat as fresh so no STALE label is shown
        usage_fetch_rc=0
    fi

    if [[ "$usage_fetch_rc" -eq 2 ]]; then
        # Stale data: show only 5h usage with STALE indicator
        if [[ "$five_hour_pct" -gt 0 ]] 2>/dev/null; then
            daily_color=$(get_usage_color "$five_hour_pct")
            daily_reset=$(format_time_remaining "$five_hour_resets")
            if [[ $fetched_at_check -gt 0 ]]; then
                stale_minutes=$(( data_age / 60 ))
            else
                stale_minutes="?"
            fi
            usage_info=$(printf ' | 5h: %s%s%%%s (%s) | %sSTALE (%sm)%s' \
                "$daily_color" "$five_hour_pct" "$RESET" "$daily_reset" "$RED" "$stale_minutes" "$RESET")
        fi
    else
        # Fresh data: show full breakdown
        seven_day_pct=$(parse_pct "$seven_day_util")

        if [[ "$five_hour_pct" -gt 0 ]] 2>/dev/null || [[ "$seven_day_pct" -gt 0 ]] 2>/dev/null; then
            daily_color=$(get_usage_color "$five_hour_pct")
            weekly_color=$(get_usage_color "$seven_day_pct")
            daily_reset=$(format_time_remaining "$five_hour_resets")
            weekly_reset=$(format_time_remaining "$seven_day_resets")

            usage_info=$(printf ' | 5h: %s%s%%%s (%s) | 7d: %s%s%%%s (%s)' \
                "$daily_color" "$five_hour_pct" "$RESET" "$daily_reset" \
                "$weekly_color" "$seven_day_pct" "$RESET" "$weekly_reset")
        fi

        # Extra usage (only show if enabled)
        if [[ "$extra_enabled" == "true" ]]; then
            extra_pct=$(parse_pct "$extra_util")
            extra_color=$(get_usage_color "$extra_pct")
            extra_used_int=$(printf "%.0f" "$extra_used")
            usage_info=$(printf '%s | Extra: %s%s%%%s (%s/%s)' \
                "$usage_info" "$extra_color" "$extra_pct" "$RESET" "$extra_used_int" "$extra_limit")
        fi
    fi
fi

# Build the status line (common prefix, conditional context suffix)
status=$(printf '%s%s%s in %s%s%s' "$CYAN" "$model" "$RESET" "$GREEN" "$(basename "$cwd")" "$RESET")
if [[ -n "$git_branch" ]]; then
    status=$(printf '%s on %s%s%s' "$status" "$MAGENTA" "$git_branch" "$RESET")
fi
if [[ "$has_context" == "true" ]]; then
    context_color=$(get_usage_color "$context_percentage")
    status=$(printf '%s | Ctx: %s%d%%%s' "$status" "$context_color" "$context_percentage" "$RESET")
fi
if [[ -n "$usage_info" ]]; then
    status="${status}${usage_info}"
fi

echo "$status"
