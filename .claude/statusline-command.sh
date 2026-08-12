#!/bin/bash

GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
CYAN=$'\033[36m'; MAGENTA=$'\033[35m'; RESET=$'\033[0m'
CAVEMAN_ORANGE=$'\033[38;5;172m'

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
ENTERPRISE_USAGE_TTL=60
refresh_enterprise_usage_cache() {
    local now age
    now=$(date +%s)
    if [[ -f "$ENTERPRISE_USAGE_CACHE" ]]; then
        age=$(( now - $(stat -f %m "$ENTERPRISE_USAGE_CACHE" 2>/dev/null || echo 0) ))
        [[ $age -lt $ENTERPRISE_USAGE_TTL ]] && return
    fi
    (
        local token
        token=$(security find-generic-password -s "$credentials_service" -w 2>/dev/null \
                | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
        [[ -z "$token" ]] && exit 0
        curl -sS -m 5 "https://api.anthropic.com/api/oauth/usage" \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: claude-cli/statusline (external, cli)" \
            -o "$ENTERPRISE_USAGE_CACHE.tmp" \
            && mv "$ENTERPRISE_USAGE_CACHE.tmp" "$ENTERPRISE_USAGE_CACHE"
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
            if [[ -n "$limit_minor" && "$limit_minor" != "null" ]]; then
                limit_dollars=$(format_minor_dollars "$limit_minor" "$limit_exp")
                spend_pct_int=$(parse_pct "$spend_pct")
                spend_color=$(get_usage_color "$spend_pct_int")
                spend_seg=$(printf ' | Spend: %s$%s%s/$%s (%s%s%%%s)' \
                    "$spend_color" "$used_dollars" "$RESET" "$limit_dollars" \
                    "$spend_color" "$spend_pct_int" "$RESET")
                # resets_at is rendered only when it is an epoch; ISO strings are skipped
                if [[ "$spend_resets" =~ ^[0-9]+$ ]]; then
                    spend_seg="${spend_seg} ($(format_time_remaining "$spend_resets"))"
                fi
            else
                spend_seg=$(printf ' | Spend: %s$%s%s' "$GREEN" "$used_dollars" "$RESET")
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

# The caveman plugin only deletes its flag when toggled off in-band ("stop caveman");
# if it's disabled in settings its hooks never run, leaving a stale flag. So
# settings is the source of truth: when the plugin is disabled we ignore the
# flag entirely and show no badge.
caveman_badge=""
caveman_flag="$config_dir/.caveman-active"
caveman_enabled=$(jq -r '.enabledPlugins."caveman@caveman" // false' "$config_dir/settings.json" 2>/dev/null)
if [[ "$caveman_enabled" != "true" ]]; then
    caveman_badge=""
elif [[ -L "$caveman_flag" ]]; then
    caveman_badge=""
elif [[ -f "$caveman_flag" ]]; then
    caveman_mode=$(head -c 64 "$caveman_flag" 2>/dev/null | tr -d '\n\r' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
    case "$caveman_mode" in
        off|lite|full|ultra|wenyan-lite|wenyan|wenyan-full|wenyan-ultra|commit|review|compress)
            if [[ -z "$caveman_mode" || "$caveman_mode" == "full" ]]; then
                caveman_badge=$(printf '%s[CAVEMAN]%s' "$CAVEMAN_ORANGE" "$RESET")
            else
                caveman_badge=$(printf '%s[CAVEMAN:%s]%s' "$CAVEMAN_ORANGE" "$(printf '%s' "$caveman_mode" | tr '[:lower:]' '[:upper:]')" "$RESET")
            fi
            ;;
    esac
else
    caveman_badge=$(printf '%s[CAVEMAN:OFF]%s' "$CAVEMAN_ORANGE" "$RESET")
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
if [[ -n "$caveman_badge" ]]; then
    status="${status} ${caveman_badge}"
fi

echo "$status"
