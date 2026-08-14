#!/bin/bash

GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
CYAN=$'\033[36m'; MAGENTA=$'\033[35m'; RESET=$'\033[0m'

# Per-account state lives under the active config dir, not $HOME. Claude Code
# namespaces the keychain credential by the config dir path (sha256 prefix),
# leaving the bare service name to the default profile — so a work profile must
# not read the private account's token or config.
config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
credentials_service="Claude Code-credentials"
profile_suffix=""
# The default profile keeps its config json at $HOME, beside ~/.claude rather
# than inside it; custom config dirs keep theirs within.
config_json="$HOME/.claude.json"
if [[ "$config_dir" != "$HOME/.claude" ]]; then
    profile_suffix="-$(printf '%s' "$config_dir" | shasum -a 256 | cut -c1-8)"
    credentials_service="${credentials_service}${profile_suffix}"
    config_json="$config_dir/.claude.json"
fi

input=$(</dev/stdin)

IFS=$'\t' read -r model cwd current size <<< "$(jq -r '[
  .model.display_name,
  .workspace.current_dir,
  ((.context_window.current_usage // {}) | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))),
  (.context_window.context_window_size // 0)
] | @tsv' <<< "$input")"

has_context=false
context_percentage=0
if [[ "$current" != "0" || "$size" != "0" ]] && [[ "$size" -gt 0 ]] 2>/dev/null; then
    has_context=true
    context_percentage=$((current * 100 / size))
fi

# Skip optional locks so a concurrent git operation can't block the render.
git_branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    git_branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
fi

# Large context windows get tighter thresholds: the same percentage leaves far
# less absolute headroom.
get_usage_color() {
    local util=${1%.*}
    local ctx_size=${2:-0}
    local low=50 high=75
    if [[ "$ctx_size" -ge 500000 ]] 2>/dev/null; then
        low=30; high=40
    fi
    if [[ $util -lt $low ]]; then
        echo "$GREEN"
    elif [[ $util -lt $high ]]; then
        echo "$YELLOW"
    else
        echo "$RED"
    fi
}

format_reset_time() {
    local reset_time=$1
    if [[ -z "$reset_time" || "$reset_time" == "0" ]]; then
        echo "?"
        return
    fi
    date -r "$reset_time" +%-I%p | tr '[:upper:]' '[:lower:]'
}

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
        local hours=$((diff / 3600))
        local mins=$(( (diff % 3600) / 60 ))
        echo "${hours}h${mins}m"
    else
        local days=$(echo "scale=0; ($diff + 43200) / 86400" | bc)
        echo "${days}d"
    fi
}

# Epoch of the anchor day at midnight within the month starting at $1, clamped
# to the month's length so a day-31 anchor still lands in February.
anchor_in_month() {
    local month_first=$1 day=$2 days_in_month
    days_in_month=$(date -r "$month_first" -v+1m -v-1d +%-d)
    [[ $day -gt $days_in_month ]] && day=$days_in_month
    date -r "$month_first" -v"+$((day - 1))d" +%s
}

# Emits "<cycle_start> <cycle_end>" for the monthly spend window. Month steps go
# through the 1st because stepping a month off day 31 rolls over into the wrong
# month on BSD date.
spend_cycle_bounds() {
    local anchor_day=$1 now month_first boundary
    now=$(date +%s)
    month_first=$(date -r "$now" -v1d -v0H -v0M -v0S +%s)
    boundary=$(anchor_in_month "$month_first" "$anchor_day")
    if [[ $boundary -gt $now ]]; then
        echo "$(anchor_in_month "$(date -r "$month_first" -v-1m +%s)" "$anchor_day") $boundary"
    else
        echo "$boundary $(anchor_in_month "$(date -r "$month_first" -v+1m +%s)" "$anchor_day")"
    fi
}

# Epoch at which the remaining budget runs out if spending continues at the
# cycle's average rate so far. Empty when there is nothing to extrapolate from.
project_exhaustion() {
    local used=$1 limit=$2 cycle_start=$3
    local now elapsed
    now=$(date +%s)
    elapsed=$((now - cycle_start))
    [[ $elapsed -le 0 || $used -le 0 || $used -ge $limit ]] && return
    awk -v now="$now" -v used="$used" -v limit="$limit" -v elapsed="$elapsed" \
        'BEGIN { printf "%d", now + (limit - used) * elapsed / used }'
}

parse_pct() {
    local v=$1
    if [[ -n "$v" && "$v" != "null" ]]; then
        printf "%.0f" "$v"
    else
        echo "0"
    fi
}

format_minor_dollars() {
    awk "BEGIN { printf \"%.2f\", ${1:-0} / (10 ^ ${2:-2}) }"
}

# Usage-based enterprise seats are billed in dollars, not 5h/7d windows, so the
# native statusline JSON carries no rate_limits block for them. Refresh the org
# spend from the OAuth usage API into a cache, in the background so the render
# never blocks: this invocation shows whatever cache exists, the fetched value
# lands on the next refresh. Fully detached (>/dev/null) so the harness doesn't
# wait on the child's pipes.
ENTERPRISE_USAGE_CACHE="${TMPDIR:-/tmp}/claude-enterprise-usage${profile_suffix}.json"
ENTERPRISE_USAGE_FAIL="$ENTERPRISE_USAGE_CACHE.fail"
ENTERPRISE_USAGE_LOCK="$ENTERPRISE_USAGE_CACHE.lock"
# The spend cycle has no reset timestamp in the API payload, so the anchor day is
# learned from observed resets and kept outside $TMPDIR — losing it would cost a
# whole billing cycle to relearn.
ENTERPRISE_CYCLE_STATE_DIR="$config_dir/statusline"
ENTERPRISE_CYCLE_ANCHOR="$ENTERPRISE_CYCLE_STATE_DIR/spend-cycle-anchor"
ENTERPRISE_CYCLE_LAST="$ENTERPRISE_CYCLE_STATE_DIR/spend-last-used"
ENTERPRISE_USAGE_TTL=300
# The endpoint rate limits aggressively, so a failed fetch parks further attempts
# instead of retrying every TTL and digging the hole deeper.
ENTERPRISE_USAGE_BACKOFF=600
# A lock orphaned by a killed render must not wedge refreshes forever.
ENTERPRISE_USAGE_LOCK_TIMEOUT=120
# A cycle rollover shows up as spend falling off a cliff, which is the only
# signal available for when the month turns over. Anything short of a halving is
# a refund or an adjustment; a drop first seen after this long says nothing about
# which day it happened on.
ENTERPRISE_CYCLE_MAX_DETECT_GAP=172800

file_age() {
    local mtime
    mtime=$(stat -f %m "$1" 2>/dev/null) || return 1
    echo $(( $(date +%s) - mtime ))
}

learn_cycle_anchor() {
    local payload=$1 used prev prev_age
    used=$(jq -r '(.spend.used.amount_minor // "")' "$payload" 2>/dev/null)
    [[ "$used" =~ ^[0-9]+$ ]] || return
    prev=$(cat "$ENTERPRISE_CYCLE_LAST" 2>/dev/null)
    prev_age=$(file_age "$ENTERPRISE_CYCLE_LAST")
    mkdir -p "$ENTERPRISE_CYCLE_STATE_DIR" 2>/dev/null
    # A drop seen after a long silence says nothing about which day it happened
    # on, so it updates the baseline without moving the anchor.
    if [[ "$prev" =~ ^[0-9]+$ && $prev -gt 0 && $((used * 2)) -lt $prev ]] \
       && [[ -n "$prev_age" && $prev_age -lt $ENTERPRISE_CYCLE_MAX_DETECT_GAP ]]; then
        date +%-d > "$ENTERPRISE_CYCLE_ANCHOR"
    fi
    printf '%s' "$used" > "$ENTERPRISE_CYCLE_LAST"
}

refresh_enterprise_usage_cache() {
    local age
    if age=$(file_age "$ENTERPRISE_USAGE_CACHE") && [[ $age -lt $ENTERPRISE_USAGE_TTL ]]; then
        return
    fi
    if age=$(file_age "$ENTERPRISE_USAGE_FAIL") && [[ $age -lt $ENTERPRISE_USAGE_BACKOFF ]]; then
        return
    fi
    # Every open session re-renders on a timer, so without a lock they all fire a
    # request in the same tick the moment the cache goes stale — which is what
    # earns the rate limiting in the first place.
    if ! mkdir "$ENTERPRISE_USAGE_LOCK" 2>/dev/null; then
        if age=$(file_age "$ENTERPRISE_USAGE_LOCK") && [[ $age -gt $ENTERPRISE_USAGE_LOCK_TIMEOUT ]]; then
            rmdir "$ENTERPRISE_USAGE_LOCK" 2>/dev/null
        fi
        return
    fi
    (
        trap 'rmdir "$ENTERPRISE_USAGE_LOCK" 2>/dev/null' EXIT
        local token tmp code
        token=$(security find-generic-password -s "$credentials_service" -w 2>/dev/null \
                | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
        [[ -z "$token" ]] && { : > "$ENTERPRISE_USAGE_FAIL"; exit 0; }
        # Per-PID so concurrent fetches can't interleave into one another's file.
        tmp="$ENTERPRISE_USAGE_CACHE.$BASHPID.tmp"
        code=$(curl -sS -m 5 -w '%{http_code}' "https://api.anthropic.com/api/oauth/usage" \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: claude-cli/statusline (external, cli)" \
            -o "$tmp")
        # curl exits 0 on a 429 or 401, so the status and payload shape decide:
        # only a real usage body may replace the last known good value.
        if [[ "$code" == "200" ]] && jq -e '.spend' "$tmp" >/dev/null 2>&1; then
            learn_cycle_anchor "$tmp"
            mv "$tmp" "$ENTERPRISE_USAGE_CACHE"
            rm -f "$ENTERPRISE_USAGE_FAIL"
        else
            rm -f "$tmp"
            : > "$ENTERPRISE_USAGE_FAIL"
        fi
    ) >/dev/null 2>&1 &
    disown 2>/dev/null
}

# Account type drives which usage model applies. seatTier lives in the main
# config file (plain read — no keychain hit on every refresh); the keychain is
# only touched by the throttled background fetch above.
usage_info=""
account_seat=$(jq -r '.oauthAccount.seatTier // ""' "$config_json" 2>/dev/null)

if [[ "$account_seat" == "enterprise_usage_based" ]]; then
    refresh_enterprise_usage_cache

    session_cost=$(jq -r '(.cost.total_cost_usd // 0)' <<< "$input")
    if [[ -n "$session_cost" && "$session_cost" != "null" ]]; then
        usage_info=$(printf ' | Sess: %s$%.2f%s' "$GREEN" "$session_cost" "$RESET")
    fi

    if [[ -f "$ENTERPRISE_USAGE_CACHE" ]]; then
        IFS=$'\x1e' read -r spend_enabled used_minor used_exp limit_minor limit_exp spend_pct spend_resets \
            <<< "$(jq -r '[
              (.spend.enabled // false),
              (.spend.used.amount_minor // 0),
              (.spend.used.exponent // 2),
              (.spend.limit.amount_minor // ""),
              (.spend.limit.exponent // 2),
              (.spend.percent // 0),
              (.nimbus_quill.resets_at // "")
            ] | join("")' "$ENTERPRISE_USAGE_CACHE" 2>/dev/null)"

        if [[ "$spend_enabled" == "true" ]]; then
            used_dollars=$(format_minor_dollars "$used_minor" "$used_exp")
            # The cache is served past its TTL rather than dropping the segment,
            # so a failed refresh has to admit the number is last known good.
            stale_marker=""
            [[ -f "$ENTERPRISE_USAGE_FAIL" ]] && stale_marker="~"
            if [[ -n "$limit_minor" && "$limit_minor" != "null" ]]; then
                limit_dollars=$(format_minor_dollars "$limit_minor" "$limit_exp")
                spend_pct_int=$(parse_pct "$spend_pct")
                spend_color=$(get_usage_color "$spend_pct_int")
                spend_seg=$(printf ' | Spend: %s%s$%s%s/$%s (%s%s%%%s)' \
                    "$spend_color" "$stale_marker" "$used_dollars" "$RESET" "$limit_dollars" \
                    "$spend_color" "$spend_pct_int" "$RESET")

                # An epoch resets_at is authoritative; the derived monthly cycle
                # only covers for the payload not carrying one at all.
                if [[ "$spend_resets" =~ ^[0-9]+$ ]]; then
                    cycle_end=$spend_resets
                    cycle_start=""
                else
                    anchor_day=$(cat "$ENTERPRISE_CYCLE_ANCHOR" 2>/dev/null)
                    [[ "$anchor_day" =~ ^[0-9]+$ ]] || anchor_day=1
                    read -r cycle_start cycle_end <<< "$(spend_cycle_bounds "$anchor_day")"
                fi

                # The run-out estimate is the point of the segment, so it is only
                # worth screen space while it still lands inside this cycle.
                dry_seg=""
                if [[ -n "$cycle_start" ]]; then
                    dry_ts=$(project_exhaustion "$used_minor" "$limit_minor" "$cycle_start")
                    if [[ -n "$dry_ts" && $dry_ts -lt $cycle_end ]]; then
                        dry_seg=$(printf ' %sdry %s%s <' "$RED" "$(format_time_remaining "$dry_ts")" "$RESET")
                    fi
                fi
                spend_seg="${spend_seg}${dry_seg} reset $(format_time_remaining "$cycle_end")"
            else
                spend_seg=$(printf ' | Spend: %s%s$%s%s' "$GREEN" "$stale_marker" "$used_dollars" "$RESET")
            fi
            usage_info="${usage_info}${spend_seg}"
        fi
    fi
else
    # Subscription (Pro/Max) accounts: 5h/7d rate_limits from the native
    # statusline JSON (added in v2.1.80), replacing the old /api/oauth/usage
    # workaround that fetched directly.
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
fi

status=$(printf '%s%s%s in %s%s%s' "$CYAN" "$model" "$RESET" "$GREEN" "$(basename "$cwd")" "$RESET")
if [[ -n "$git_branch" ]]; then
    status=$(printf '%s on %s%s%s' "$status" "$MAGENTA" "$git_branch" "$RESET")
fi
if [[ "$has_context" == "true" ]]; then
    context_color=$(get_usage_color "$context_percentage" "$size")
    status=$(printf '%s | Ctx: %s%d%%%s' "$status" "$context_color" "$context_percentage" "$RESET")
fi
if [[ -n "$usage_info" ]]; then
    status="${status}${usage_info}"
fi

echo "$status"
